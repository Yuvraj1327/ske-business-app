import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../salesmen/presentation/providers/salesman_providers.dart' show salesmenListProvider;
import '../../domain/picklist_models.dart';
import '../providers/picklist_providers.dart';

/// Picklist detail: a clean, column-based list of deliveries (Picklist No,
/// Customer, Invoice, Salesman, Amount Payable) — never the raw Excel.
/// Each pending row lets the Delivery Agent (or Admin) pick Cash / Online /
/// Credit / Cheque (Credit also takes the Salesman who will handle it, Cheque
/// the cheque amount) and confirm it. Once confirmed, a row becomes read-only (the
/// backend disallows re-confirming — see PicklistService.confirm_item),
/// showing its final status instead.
class PicklistDetailScreen extends ConsumerWidget {
  const PicklistDetailScreen({super.key, required this.picklistId});

  final String picklistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(picklistDetailProvider(picklistId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(picklistDetailProvider(picklistId)),
        ),
        data: (picklist) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(picklist.picklistNo, style: AppTextStyles.heading1),
              const SizedBox(height: 2),
              Text(
                '${picklist.deliveryAgentName}${picklist.psrRoute != null ? ' · ${picklist.psrRoute}' : ''}',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 4),
              Text('Total: ${Formatters.currency(picklist.totalAmount)}', style: AppTextStyles.amount),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: picklist.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _PicklistItemCard(picklistId: picklistId, item: picklist.items[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PicklistItemCard extends ConsumerStatefulWidget {
  const _PicklistItemCard({required this.picklistId, required this.item});

  final String picklistId;
  final PicklistItem item;

  @override
  ConsumerState<_PicklistItemCard> createState() => _PicklistItemCardState();
}

class _PicklistItemCardState extends ConsumerState<_PicklistItemCard> {
  String? _selectedStatus;
  String? _selectedSalesmanId;
  late final TextEditingController _chequeAmountController =
      TextEditingController(text: widget.item.amountPayable.toStringAsFixed(2));

  @override
  void dispose() {
    _chequeAmountController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'cash':
      case 'online':
      case 'cheque':
        return AppColors.success;
      case 'credit':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _confirm() async {
    if (_selectedStatus == null) return;

    double? chequeAmount;
    if (_selectedStatus == 'cheque') {
      chequeAmount = double.tryParse(_chequeAmountController.text.trim());
      final error = chequeAmount == null || chequeAmount <= 0
          ? 'Enter the cheque amount.'
          : chequeAmount > widget.item.amountPayable
              ? 'Cheque amount cannot exceed ${Formatters.currency(widget.item.amountPayable)}.'
              : null;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error),
        );
        return;
      }
    }

    String? salesmanId;
    if (_selectedStatus == 'credit') {
      salesmanId = _selectedSalesmanId;
      if (salesmanId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Select the salesman who will handle this credit.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    final success = await ref.read(picklistMutationControllerProvider.notifier).confirmItem(
          widget.picklistId,
          widget.item.id,
          _selectedStatus!,
          chequeAmount: chequeAmount,
          salesmanId: salesmanId,
        );

    if (!mounted) return;
    if (!success) {
      final state = ref.read(picklistMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  /// Return actions reuse the existing Sales Return screen for this row's
  /// sale; only the pre-filled reason / quantities differ.
  Widget _returnOption(String label, {required String reason, bool full = false}) {
    return OutlinedButton(
      onPressed: () => context.push(
        Uri(path: '/sales/${widget.item.saleId}/return', queryParameters: {'reason': reason, if (full) 'full': '1'})
            .toString(),
      ),
      child: Text(label),
    );
  }

  /// Active salesmen from the existing GET /salesmen; the Delivery Agent
  /// picks who will handle this Credit/Udhaar customer.
  Widget _buildSalesmanDropdown() {
    final salesmenAsync = ref.watch(salesmenListProvider);
    return salesmenAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Row(
        children: [
          Expanded(child: Text('Could not load salesmen: ${e is Failure ? e.message : e}')),
          TextButton(onPressed: () => ref.invalidate(salesmenListProvider), child: const Text('Retry')),
        ],
      ),
      data: (salesmen) => DropdownButtonFormField<String>(
        value: salesmen.any((s) => s.id == _selectedSalesmanId) ? _selectedSalesmanId : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Salesman'),
        items: salesmen.map((s) => DropdownMenuItem(value: s.id, child: Text(s.fullName))).toList(),
        onChanged: (v) => setState(() => _selectedSalesmanId = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final mutationState = ref.watch(picklistMutationControllerProvider);
    final isPending = item.status == 'pending';

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
                Text(Formatters.currency(item.amountPayable), style: AppTextStyles.amount),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Invoice ${item.invoiceNumber}${item.salesmanLabel != null ? ' · ${item.salesmanLabel}' : ''}',
              style: AppTextStyles.bodySecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (isPending) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'online', label: Text('Online')),
                  ButtonSegment(value: 'credit', label: Text('Credit')),
                  ButtonSegment(value: 'cheque', label: Text('Cheque')),
                ],
                selected: _selectedStatus == null ? const {} : {_selectedStatus!},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) => setState(() => _selectedStatus = s.isEmpty ? null : s.first),
              ),
              if (_selectedStatus == 'credit') ...[
                const SizedBox(height: 10),
                _buildSalesmanDropdown(),
              ],
              if (_selectedStatus == 'cheque') ...[
                const SizedBox(height: 10),
                AppTextField(
                  label: 'Cheque Amount',
                  controller: _chequeAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedStatus == null || mutationState.isLoading ? null : _confirm,
                  child: mutationState.isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save / Confirm'),
                ),
              ),
              if (item.saleId != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _returnOption('Full Return', reason: 'Full return', full: true),
                    _returnOption('Partial Return', reason: 'Partial return'),
                    _returnOption('Damaged', reason: 'Damaged'),
                    _returnOption('Wrong Item', reason: 'Wrong item'),
                  ],
                ),
              ],
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  label: item.status == 'cheque'
                      ? 'cheque · ${Formatters.currency(item.chequeAmount)}'
                      : item.status,
                  color: _statusColor(item.status),
                ),
              ),
              if (item.status == 'credit' && item.creditSalesmanName != null) ...[
                const SizedBox(height: 6),
                Text('Salesman: ${item.creditSalesmanName}', style: AppTextStyles.bodySecondary),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
