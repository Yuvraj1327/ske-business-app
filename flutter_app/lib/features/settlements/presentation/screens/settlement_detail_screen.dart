import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/settlement_models.dart';
import '../providers/settlement_providers.dart';

/// Full detail of one Settlement Sheet. What a viewer can DO here depends
/// on who they are relative to the sheet (checked client-side only for
/// UX — the real enforcement is server-side in SettlementService):
///   - Admin: move the sheet Draft -> In Progress -> Completed, and (if
///     needed) fill in either half of any row.
///   - The assigned Delivery Agent: update each row's delivery half while
///     the sheet is 'in_progress'.
///   - The assigned Salesman: update each row's Credit/Udhaar half while
///     the sheet is 'in_progress'.
class SettlementDetailScreen extends ConsumerWidget {
  const SettlementDetailScreen({super.key, required this.sheetId});

  final String sheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(settlementDetailProvider(sheetId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(settlementDetailProvider(sheetId)),
        ),
        data: (sheet) {
          final isAdmin = user?.isAdmin ?? false;
          final isAgent = user != null && user.id == sheet.deliveryAgentId;
          final isSalesman = user != null && user.id == sheet.salesmanId;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(sheet: sheet, isAdmin: isAdmin),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: sheet.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ItemCard(
                    sheet: sheet,
                    item: sheet.items[i],
                    canEditDelivery: (isAdmin || isAgent) && sheet.status == 'in_progress',
                    canEditCredit: (isAdmin || isSalesman) && sheet.status == 'in_progress',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.sheet, required this.isAdmin});

  final SettlementSheetDetail sheet;
  final bool isAdmin;

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    final success =
        await ref.read(settlementMutationControllerProvider.notifier).updateStatus(sheet.id, newStatus);
    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(settlementMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutationState = ref.watch(settlementMutationControllerProvider);
    final summary = sheet.summary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(sheet.sheetNo, style: AppTextStyles.heading1)),
                StatusBadge(label: Formatters.roleLabel(sheet.status), color: _statusColor(sheet.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.date(sheet.sheetDate)} · Agent: ${sheet.deliveryAgentName} · Salesman: ${sheet.salesmanName}',
              style: AppTextStyles.bodySecondary,
            ),
            if (sheet.notes != null && sheet.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(sheet.notes!, style: AppTextStyles.body),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _StatLabel(label: 'Total Invoice', value: Formatters.currency(summary.totalInvoiceAmount)),
                _StatLabel(label: 'Collected', value: Formatters.currency(summary.totalCollected)),
                _StatLabel(label: 'Credit Outstanding', value: Formatters.currency(summary.totalCreditOutstanding)),
                _StatLabel(label: 'Pending Rows', value: '${summary.pending}'),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (sheet.status == 'draft')
                    AppButton(
                      label: 'Start (Move to In Progress)',
                      expand: false,
                      isLoading: mutationState.isLoading,
                      onPressed: () => _changeStatus(context, ref, 'in_progress'),
                    ),
                  if (sheet.status == 'in_progress')
                    AppButton(
                      label: 'Complete Sheet',
                      expand: false,
                      isLoading: mutationState.isLoading,
                      onPressed: () => _changeStatus(context, ref, 'completed'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.amount),
      ],
    );
  }
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({
    required this.sheet,
    required this.item,
    required this.canEditDelivery,
    required this.canEditCredit,
  });

  final SettlementSheetDetail sheet;
  final SettlementSheetItem item;
  final bool canEditDelivery;
  final bool canEditCredit;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  bool _editingDelivery = false;
  bool _editingCredit = false;

  late String _deliveryStatus = widget.item.deliveryStatus == 'pending' ? 'delivered' : widget.item.deliveryStatus;
  late final TextEditingController _amountCollectedController =
      TextEditingController(text: widget.item.amountCollected.toStringAsFixed(2));
  String _paymentMode = 'cash';
  late final TextEditingController _agentNotesController = TextEditingController(text: widget.item.agentNotes ?? '');

  late final TextEditingController _creditCollectedController =
      TextEditingController(text: widget.item.creditCollected.toStringAsFixed(2));
  late final TextEditingController _salesmanNotesController =
      TextEditingController(text: widget.item.salesmanNotes ?? '');

  @override
  void dispose() {
    _amountCollectedController.dispose();
    _agentNotesController.dispose();
    _creditCollectedController.dispose();
    _salesmanNotesController.dispose();
    super.dispose();
  }

  Color _deliveryColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.success;
      case 'not_delivered':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _saveDelivery() async {
    final amount = double.tryParse(_amountCollectedController.text.trim()) ?? 0;
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateItemDelivery(
          sheetId: widget.sheet.id,
          itemId: widget.item.id,
          deliveryStatus: _deliveryStatus,
          amountCollected: _deliveryStatus == 'not_delivered' ? 0 : amount,
          paymentMode: _deliveryStatus == 'not_delivered' ? 'none' : _paymentMode,
          agentNotes: _agentNotesController.text.trim().isEmpty ? null : _agentNotesController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingDelivery = false);
    } else {
      _showError();
    }
  }

  Future<void> _saveCredit() async {
    final collected = double.tryParse(_creditCollectedController.text.trim()) ?? 0;
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateItemCredit(
          sheetId: widget.sheet.id,
          itemId: widget.item.id,
          creditCollected: collected,
          salesmanNotes: _salesmanNotesController.text.trim().isEmpty ? null : _salesmanNotesController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingCredit = false);
    } else {
      _showError();
    }
  }

  void _showError() {
    final state = ref.read(settlementMutationControllerProvider);
    final failure = state.hasError ? state.error as Failure : Failure.unknown();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final mutationState = ref.watch(settlementMutationControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.customerName, style: AppTextStyles.heading3, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(Formatters.currency(item.invoiceAmount), style: AppTextStyles.amount),
              ],
            ),
            if (item.customerCode != null) Text('Code: ${item.customerCode}', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusBadge(label: Formatters.roleLabel(item.deliveryStatus), color: _deliveryColor(item.deliveryStatus)),
                if (item.amountCollected > 0)
                  StatusBadge(label: '${Formatters.currency(item.amountCollected)} (${item.paymentMode})', color: AppColors.success),
                if (item.creditAmount > 0)
                  StatusBadge(
                    label: 'Credit ${Formatters.currency(item.creditCollected)}/${Formatters.currency(item.creditAmount)}',
                    color: item.creditOutstanding > 0 ? AppColors.warning : AppColors.success,
                  ),
              ],
            ),
            if (widget.canEditDelivery && !_editingDelivery)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _editingDelivery = true), child: const Text('Update Delivery')),
              ),
            if (_editingDelivery) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deliveryStatus,
                      decoration: const InputDecoration(labelText: 'Delivery Status'),
                      items: const [
                        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(value: 'not_delivered', child: Text('Not Delivered')),
                      ],
                      onChanged: (v) => setState(() => _deliveryStatus = v ?? _deliveryStatus),
                    ),
                  ),
                ],
              ),
              if (_deliveryStatus != 'not_delivered') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit (goes to Udhaar)')),
                  ],
                  onChanged: (v) => setState(() => _paymentMode = v ?? _paymentMode),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountCollectedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount Collected'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _agentNotesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingDelivery = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveDelivery),
                ],
              ),
            ],
            if (widget.canEditCredit && !_editingCredit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _editingCredit = true), child: const Text('Update Credit / Udhaar')),
              ),
            if (_editingCredit) ...[
              const Divider(),
              Text('Credit Amount: ${Formatters.currency(item.creditAmount)}', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 10),
              TextField(
                controller: _creditCollectedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Credit Collected (total so far)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _salesmanNotesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingCredit = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveCredit),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
