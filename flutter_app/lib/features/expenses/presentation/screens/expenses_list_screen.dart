import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/expense_models.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_form_dialog.dart';

class ExpensesListScreen extends ConsumerWidget {
  const ExpensesListScreen({super.key});

  Future<void> _voidExpense(BuildContext context, WidgetRef ref, Expense expense) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Void this expense?',
      message: 'This marks the expense as voided. Any linked cash/UPI/bank transaction is not automatically reversed.',
      confirmLabel: 'Void Expense',
    );
    if (!confirmed) return;

    final success = await ref.read(expenseMutationControllerProvider.notifier).voidExpense(expense.id);
    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(expenseMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesListProvider);
    final filter = ref.watch(expensesFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Expenses', style: AppTextStyles.heading1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Expense'),
                onPressed: () => showExpenseFormDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: expensesAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(expensesListProvider),
              ),
              data: (expensePage) {
                if (expensePage.items.isEmpty) {
                  return const EmptyStateView(message: 'No expenses recorded yet.', icon: Icons.receipt_long_outlined);
                }
                return Column(
                  children: [
                    Card(
                      color: context.subtleSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total (active)', style: AppTextStyles.bodySecondary),
                            Text(
                              Formatters.currency(expensePage.totalAmount),
                              style: AppTextStyles.heading3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: expensePage.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final expense = expensePage.items[index];
                          return ListTile(
                            title: Text(expense.categoryName, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${Formatters.date(expense.expenseDate)}${expense.description != null ? ' · ${expense.description}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Formatters.currency(expense.amount), style: AppTextStyles.body),
                                const SizedBox(width: 8),
                                if (expense.status == 'voided')
                                  const StatusBadge(label: 'Voided', color: AppColors.statusCancelled)
                                else
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                    tooltip: 'Void',
                                    onPressed: () => _voidExpense(context, ref, expense),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${expensePage.total} expense(s) · Page ${expensePage.page} of ${expensePage.totalPages}',
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: expensePage.page > 1
                                  ? () => ref.read(expensesFilterProvider.notifier).state = filter.copyWith(page: expensePage.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: expensePage.hasNextPage
                                  ? () => ref.read(expensesFilterProvider.notifier).state = filter.copyWith(page: expensePage.page + 1)
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
