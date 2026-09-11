import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_form_dialog.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final filter = ref.watch(transactionsFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Cash / UPI / Bank', style: AppTextStyles.heading1),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Transaction'),
                onPressed: () => showTransactionFormDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: filter.transactionType == null,
                onSelected: (_) => ref.read(transactionsFilterProvider.notifier).state = filter.copyWith(clearType: true, page: 1),
              ),
              ChoiceChip(
                label: const Text('Cash'),
                selected: filter.transactionType == 'cash',
                onSelected: (_) => ref.read(transactionsFilterProvider.notifier).state = filter.copyWith(transactionType: 'cash', page: 1),
              ),
              ChoiceChip(
                label: const Text('UPI'),
                selected: filter.transactionType == 'upi',
                onSelected: (_) => ref.read(transactionsFilterProvider.notifier).state = filter.copyWith(transactionType: 'upi', page: 1),
              ),
              ChoiceChip(
                label: const Text('Bank'),
                selected: filter.transactionType == 'bank',
                onSelected: (_) => ref.read(transactionsFilterProvider.notifier).state = filter.copyWith(transactionType: 'bank', page: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(transactionsListProvider),
              ),
              data: (txnPage) {
                if (txnPage.items.isEmpty) {
                  return const EmptyStateView(message: 'No transactions recorded yet.', icon: Icons.account_balance_wallet_outlined);
                }
                return Column(
                  children: [
                    Card(
                      color: context.subtleSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _totalTile('In', txnPage.totalIn, AppColors.success),
                            _totalTile('Out', txnPage.totalOut, AppColors.error),
                            _totalTile('Net', txnPage.totalIn - txnPage.totalOut, AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: txnPage.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final txn = txnPage.items[index];
                          final isIn = txn.direction == 'in';
                          return ListTile(
                            leading: Icon(
                              isIn ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIn ? AppColors.success : AppColors.error,
                            ),
                            title: Text('${txn.transactionType.toUpperCase()} ${isIn ? 'In' : 'Out'}'),
                            subtitle: Text(
                              '${Formatters.date(txn.transactionDate)}'
                              '${txn.referenceNote != null ? ' · ${txn.referenceNote}' : ''}'
                              '${txn.relatedPaymentId != null ? ' · from payment' : ''}',
                            ),
                            trailing: Text(
                              '${isIn ? '+' : '−'}${Formatters.currency(txn.amount)}',
                              style: AppTextStyles.body.copyWith(color: isIn ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${txnPage.total} transaction(s) · Page ${txnPage.page} of ${txnPage.totalPages}', style: AppTextStyles.caption),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: txnPage.page > 1
                                  ? () => ref.read(transactionsFilterProvider.notifier).state = filter.copyWith(page: txnPage.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: txnPage.hasNextPage
                                  ? () => ref.read(transactionsFilterProvider.notifier).state = filter.copyWith(page: txnPage.page + 1)
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

  Widget _totalTile(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(Formatters.currency(value), style: AppTextStyles.heading3.copyWith(color: color)),
      ],
    );
  }
}
