import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/permission.dart';
import '../../../../core/permissions/permission_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/sale_providers.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.statusPaid;
      case 'partial':
        return AppColors.statusPartial;
      default:
        return AppColors.statusUnpaid;
    }
  }

  Future<void> _cancelSale(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this sale?',
      message: 'This marks the sale as cancelled. Any payments already recorded are not automatically reversed.',
      confirmLabel: 'Cancel Sale',
    );
    if (!confirmed) return;

    final success = await ref.read(saleMutationControllerProvider.notifier).cancelSale(saleId);
    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(saleMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleDetailProvider(saleId));
    final canCancel = ref.watch(hasPermissionProvider(Permission.salesCancel));
    final canRecordPayment = ref.watch(hasPermissionProvider(Permission.paymentsCreate));
    final canReturn = ref.watch(hasPermissionProvider(Permission.returnsCreate));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: saleAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(saleDetailProvider(saleId)),
        ),
        data: (sale) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(sale.invoice?.invoiceNumber ?? 'Sale', style: AppTextStyles.heading1),
                    ),
                    StatusBadge(label: sale.paymentStatus, color: _statusColor(sale.paymentStatus)),
                    if (sale.status == 'cancelled') ...[
                      const SizedBox(width: 8),
                      const StatusBadge(label: 'Cancelled', color: AppColors.statusCancelled),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('${sale.customerName} · ${Formatters.date(sale.saleDate)}', style: AppTextStyles.bodySecondary),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items', style: AppTextStyles.heading3),
                        const Divider(),
                        ...sale.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text('${item.productName}\n${item.quantity} × ${Formatters.currency(item.unitPrice)}',
                                      style: AppTextStyles.bodySecondary),
                                ),
                                Text(Formatters.currency(item.lineTotal), style: AppTextStyles.body),
                              ],
                            ),
                          ),
                        ),
                        const Divider(),
                        _totalRow('Subtotal', sale.subtotal),
                        _totalRow('Discount', -sale.discountAmount),
                        _totalRow('Total', sale.totalAmount, bold: true),
                        _totalRow('Paid', sale.paidAmount),
                        _totalRow('Outstanding', sale.outstandingAmount, bold: true, color: AppColors.error),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (canRecordPayment && sale.status == 'active')
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Record Payment'),
                          onPressed: () => context.go('/payments/new?customerId=${sale.customerId}&saleId=${sale.id}'),
                        ),
                      ),
                    if (canReturn && sale.status == 'active') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.assignment_return_outlined, size: 18),
                          label: const Text('Create Return'),
                          onPressed: () => context.go('/sales/${sale.id}/return'),
                        ),
                      ),
                    ],
                    if (canCancel && sale.status == 'active') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                          label: const Text('Cancel Sale', style: TextStyle(color: AppColors.error)),
                          onPressed: () => _cancelSale(context, ref),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false, Color? color}) {
    final style = (bold ? AppTextStyles.heading3 : AppTextStyles.body).copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(Formatters.currency(value), style: style)],
      ),
    );
  }
}
