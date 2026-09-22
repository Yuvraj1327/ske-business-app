import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/settlement_models.dart';
import '../providers/settlement_providers.dart';

/// Full detail of one Settlement Sheet, redesigned as a structured form
/// (mirroring the client's paper "Cash / Credit Settlement Sheet") instead
/// of a spreadsheet: a Settlement Summary section for the route-level
/// totals, followed by the existing Customer-wise Details list.
///
/// One shared screen for everyone — what a viewer can DO here depends on
/// who they are relative to the sheet (checked client-side only for UX —
/// the real enforcement is server-side in SettlementService):
///   - Admin: move the sheet Draft -> In Progress -> Completed (final
///     confirmation), edit the Old Short carry-forward figure, and (if
///     needed) fill in any other field.
///   - The assigned Delivery Agent: update the route-level Returns /
///     Damage Return / Discount / Cash / Online-Bank / Cheque totals, and
///     each customer row's delivery half, while the sheet is 'in_progress'.
///   - The assigned Salesman: update the route-level Credit/Udhaar total,
///     and each customer row's Credit/Udhaar half, while 'in_progress'.
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
          final inProgress = sheet.status == 'in_progress';

          return ListView(
            children: [
              _Header(sheet: sheet, isAdmin: isAdmin),
              const SizedBox(height: 16),
              _SettlementSummaryForm(
                sheet: sheet,
                canEditAgentSummary: (isAdmin || isAgent) && inProgress,
                canEditSalesmanSummary: (isAdmin || isSalesman) && inProgress,
                canEditAdminSummary: isAdmin && sheet.status != 'completed',
              ),
              const SizedBox(height: 20),
              Text('Customer-wise Details', style: AppTextStyles.heading3),
              const SizedBox(height: 10),
              ...sheet.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItemCard(
                    sheet: sheet,
                    item: item,
                    canEditDelivery: (isAdmin || isAgent) && inProgress,
                    canEditCredit: (isAdmin || isSalesman) && inProgress,
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
            if (sheet.pickSheetNo != null && sheet.pickSheetNo!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Pick Sheet No: ${sheet.pickSheetNo}', style: AppTextStyles.caption),
            ],
            const SizedBox(height: 4),
            Text(
              '${Formatters.date(sheet.sheetDate)} · Delivery Agent: ${sheet.deliveryAgentName} · PSR/Salesman: ${sheet.salesmanName}',
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
                      label: 'Complete Sheet (Final Confirmation)',
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

/// A plain label/value row used for fields the current viewer cannot edit
/// (or that are always computed/read-only, like Day Short / Total Balance).
class _SummaryDisplayRow extends StatelessWidget {
  const _SummaryDisplayRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: emphasize ? AppTextStyles.amount : AppTextStyles.body),
        ],
      ),
    );
  }
}

/// The Settlement Summary section — the paper sheet's left-hand column of
/// route-level totals, rendered as a structured form. Three independently
/// editable groups (Delivery Agent / Salesman / Admin), each following the
/// same inline "Update -> edit fields -> Save/Cancel" pattern as the
/// customer row cards below, so the interaction stays consistent across
/// the whole screen.
class _SettlementSummaryForm extends ConsumerStatefulWidget {
  const _SettlementSummaryForm({
    required this.sheet,
    required this.canEditAgentSummary,
    required this.canEditSalesmanSummary,
    required this.canEditAdminSummary,
  });

  final SettlementSheetDetail sheet;
  final bool canEditAgentSummary;
  final bool canEditSalesmanSummary;
  final bool canEditAdminSummary;

  @override
  ConsumerState<_SettlementSummaryForm> createState() => _SettlementSummaryFormState();
}

class _SettlementSummaryFormState extends ConsumerState<_SettlementSummaryForm> {
  bool _editingAgent = false;
  bool _editingSalesman = false;
  bool _editingAdmin = false;

  late final _returnsController = TextEditingController(text: widget.sheet.returnsAmount.toStringAsFixed(2));
  late final _damageReturnController =
      TextEditingController(text: widget.sheet.damageReturnAmount.toStringAsFixed(2));
  late final _discountController = TextEditingController(text: widget.sheet.discountAmount.toStringAsFixed(2));
  late final _cashController = TextEditingController(text: widget.sheet.cashAmount.toStringAsFixed(2));
  late final _onlineController = TextEditingController(text: widget.sheet.onlineAmount.toStringAsFixed(2));
  late final _chequeController = TextEditingController(text: widget.sheet.chequeAmount.toStringAsFixed(2));

  late final _creditBillsController =
      TextEditingController(text: widget.sheet.creditBillsAmount.toStringAsFixed(2));

  late final _oldShortController = TextEditingController(text: widget.sheet.oldShortAmount.toStringAsFixed(2));

  @override
  void dispose() {
    _returnsController.dispose();
    _damageReturnController.dispose();
    _discountController.dispose();
    _cashController.dispose();
    _onlineController.dispose();
    _chequeController.dispose();
    _creditBillsController.dispose();
    _oldShortController.dispose();
    super.dispose();
  }

  Future<void> _saveAgentSummary() async {
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateAgentSummary(
          sheetId: widget.sheet.id,
          returnsAmount: double.tryParse(_returnsController.text.trim()) ?? 0,
          damageReturnAmount: double.tryParse(_damageReturnController.text.trim()) ?? 0,
          discountAmount: double.tryParse(_discountController.text.trim()) ?? 0,
          cashAmount: double.tryParse(_cashController.text.trim()) ?? 0,
          onlineAmount: double.tryParse(_onlineController.text.trim()) ?? 0,
          chequeAmount: double.tryParse(_chequeController.text.trim()) ?? 0,
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingAgent = false);
    } else {
      _showError();
    }
  }

  Future<void> _saveSalesmanSummary() async {
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateSalesmanSummary(
          sheetId: widget.sheet.id,
          creditBillsAmount: double.tryParse(_creditBillsController.text.trim()) ?? 0,
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingSalesman = false);
    } else {
      _showError();
    }
  }

  Future<void> _saveAdminSummary() async {
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateAdminSummary(
          sheetId: widget.sheet.id,
          oldShortAmount: double.tryParse(_oldShortController.text.trim()) ?? 0,
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingAdmin = false);
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
    final sheet = widget.sheet;
    final mutationState = ref.watch(settlementMutationControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settlement Summary', style: AppTextStyles.heading3),
            const Divider(),
            _SummaryDisplayRow(label: 'Pick Sheet Value', value: Formatters.currency(sheet.pickSheetValue)),

            // --- Delivery Agent (or Admin) route totals ---
            if (widget.canEditAgentSummary && !_editingAgent)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _editingAgent = true),
                  child: const Text('Update Route Totals'),
                ),
              ),
            if (_editingAgent) ...[
              const SizedBox(height: 6),
              AppTextField(
                label: 'Returns',
                controller: _returnsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Damage Return',
                controller: _damageReturnController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Discount',
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Cash',
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Online / Bank',
                controller: _onlineController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Cheque',
                controller: _chequeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingAgent = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveAgentSummary),
                ],
              ),
            ] else ...[
              _SummaryDisplayRow(label: 'Returns', value: Formatters.currency(sheet.returnsAmount)),
              _SummaryDisplayRow(label: 'Damage Return', value: Formatters.currency(sheet.damageReturnAmount)),
              _SummaryDisplayRow(label: 'Discount', value: Formatters.currency(sheet.discountAmount)),
              _SummaryDisplayRow(label: 'Cash', value: Formatters.currency(sheet.cashAmount)),
              _SummaryDisplayRow(label: 'Online / Bank', value: Formatters.currency(sheet.onlineAmount)),
              _SummaryDisplayRow(label: 'Cheque', value: Formatters.currency(sheet.chequeAmount)),
            ],

            const Divider(),

            // --- Salesman (or Admin) Credit/Udhaar total ---
            if (widget.canEditSalesmanSummary && !_editingSalesman)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _editingSalesman = true),
                  child: const Text('Update Credit / Udhaar'),
                ),
              ),
            if (_editingSalesman) ...[
              const SizedBox(height: 6),
              AppTextField(
                label: 'Credit / Udhaar (Credit Bills)',
                controller: _creditBillsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingSalesman = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(
                      label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveSalesmanSummary),
                ],
              ),
            ] else
              _SummaryDisplayRow(label: 'Credit / Udhaar', value: Formatters.currency(sheet.creditBillsAmount)),

            const Divider(),
            _SummaryDisplayRow(label: 'Day Short', value: Formatters.currency(sheet.dayShort)),

            // --- Admin-only carry-forward figure ---
            if (widget.canEditAdminSummary && !_editingAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _editingAdmin = true),
                  child: const Text('Update Old Short'),
                ),
              ),
            if (_editingAdmin) ...[
              const SizedBox(height: 6),
              AppTextField(
                label: 'Old Short',
                controller: _oldShortController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingAdmin = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveAdminSummary),
                ],
              ),
            ] else
              _SummaryDisplayRow(label: 'Old Short', value: Formatters.currency(sheet.oldShortAmount)),

            const Divider(),
            _SummaryDisplayRow(label: 'Total Balance', value: Formatters.currency(sheet.totalBalance), emphasize: true),
          ],
        ),
      ),
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
