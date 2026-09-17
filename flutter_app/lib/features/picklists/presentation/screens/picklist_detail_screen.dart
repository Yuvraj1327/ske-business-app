import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/picklist_models.dart';
import '../providers/picklist_providers.dart';

/// Picklist detail: a clean, column-based list of deliveries (Picklist No,
/// Customer, Invoice, Salesman, Amount Payable) — never the raw Excel.
/// Each pending row lets the Delivery Agent (or Admin) pick Cash / Online /
/// Credit and confirm it. Once confirmed, a row becomes read-only (the
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

  Color _statusColor(String status) {
    switch (status) {
      case 'cash':
      case 'online':
        return AppColors.success;
      case 'credit':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _confirm() async {
    if (_selectedStatus == null) return;
    final success = await ref
        .read(picklistMutationControllerProvider.notifier)
        .confirmItem(widget.picklistId, widget.item.id, _selectedStatus!);

    if (!mounted) return;
    if (!success) {
      final state = ref.read(picklistMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
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
                ],
                selected: _selectedStatus == null ? const {} : {_selectedStatus!},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) => setState(() => _selectedStatus = s.isEmpty ? null : s.first),
              ),
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
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(label: item.status, color: _statusColor(item.status)),
              ),
          ],
        ),
      ),
    );
  }
}
