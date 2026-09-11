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
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/payment_models.dart';
import '../providers/payment_providers.dart';

class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'cleared':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.statusCancelled;
    }
  }

  Future<void> _updateChequeStatus(BuildContext context, WidgetRef ref, Payment payment, String newStatus) async {
    final confirmed = await showConfirmDialog(
      context,
      title: newStatus == 'cleared' ? 'Mark cheque as cleared?' : 'Mark cheque as bounced?',
      message: newStatus == 'cleared'
          ? 'This will apply the payment toward the customer\'s outstanding balance.'
          : 'This cheque will be cancelled and will not count toward any balance.',
      confirmLabel: newStatus == 'cleared' ? 'Mark Cleared' : 'Mark Bounced',
      isDestructive: newStatus != 'cleared',
    );
    if (!confirmed) return;

    final success = await ref.read(paymentMutationControllerProvider.notifier).updateChequeStatus(payment.id, newStatus);
    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(paymentMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsListProvider);
    final filter = ref.watch(paymentsFilterProvider);
    final canManageCheques = ref.watch(hasPermissionProvider(Permission.paymentsManageChequeStatus));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Payments', style: AppTextStyles.heading1),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Payment'),
                onPressed: () => context.go('/payments/new'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: paymentsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(paymentsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(message: 'No payments recorded yet.', icon: Icons.payments_outlined);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final payment = page.items[index];
                          final isPendingCheque = payment.paymentMethod == 'cheque' && payment.status == 'pending';
                          return ListTile(
                            title: Text(payment.customerName),
                            subtitle: Text(
                              '${payment.paymentMethod.replaceAll('_', ' ').toUpperCase()} · ${Formatters.date(payment.paymentDate)}'
                              '${payment.chequeDetail != null ? ' · Cheque #${payment.chequeDetail!.chequeNumber}' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Formatters.currency(payment.amount), style: AppTextStyles.body),
                                const SizedBox(width: 8),
                                StatusBadge(label: payment.status, color: _statusColor(payment.status)),
                                if (isPendingCheque && canManageCheques) ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
                                    tooltip: 'Mark cleared',
                                    onPressed: () => _updateChequeStatus(context, ref, payment, 'cleared'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
                                    tooltip: 'Mark bounced',
                                    onPressed: () => _updateChequeStatus(context, ref, payment, 'cancelled'),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${page.total} payment(s) · Page ${page.page} of ${page.totalPages}', style: AppTextStyles.caption),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: page.page > 1
                                  ? () => ref.read(paymentsFilterProvider.notifier).state = filter.copyWith(page: page.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page.hasNextPage
                                  ? () => ref.read(paymentsFilterProvider.notifier).state = filter.copyWith(page: page.page + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
