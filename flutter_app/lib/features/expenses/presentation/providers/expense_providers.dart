import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense_models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});

final expenseCategoriesProvider = FutureProvider.autoDispose<List<ExpenseCategory>>((ref) {
  return ref.watch(expenseRepositoryProvider).listCategories();
});

class ExpensesFilter extends Equatable {
  final String? categoryId;
  final int page;

  const ExpensesFilter({this.categoryId, this.page = 1});

  ExpensesFilter copyWith({String? categoryId, bool clearCategory = false, int? page}) => ExpensesFilter(
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        page: page ?? this.page,
      );

  @override
  List<Object?> get props => [categoryId, page];
}

final expensesFilterProvider = StateProvider.autoDispose<ExpensesFilter>((ref) => const ExpensesFilter());

final expensesListProvider = FutureProvider.autoDispose<ExpensePage>((ref) {
  final filter = ref.watch(expensesFilterProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.listExpenses(page: filter.page, categoryId: filter.categoryId);
});

class ExpenseMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ExpenseRepository get _repo => ref.read(expenseRepositoryProvider);

  Future<bool> createCategory(String name) => _run(() => _repo.createCategory(name), invalidateCategories: true);

  Future<bool> createExpense({
    required String categoryId,
    required double amount,
    DateTime? expenseDate,
    String? description,
    String? paymentMethod,
  }) =>
      _run(() => _repo.createExpense(
            categoryId: categoryId,
            amount: amount,
            expenseDate: expenseDate,
            description: description,
            paymentMethod: paymentMethod,
          ));

  Future<bool> updateExpense({
    required String id,
    String? categoryId,
    double? amount,
    DateTime? expenseDate,
    String? description,
  }) =>
      _run(() => _repo.updateExpense(id: id, categoryId: categoryId, amount: amount, expenseDate: expenseDate, description: description));

  Future<bool> voidExpense(String id) => _run(() => _repo.voidExpense(id));

  Future<bool> _run(Future<dynamic> Function() action, {bool invalidateCategories = false}) async {
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(expensesListProvider);
      if (invalidateCategories) ref.invalidate(expenseCategoriesProvider);
      state = const AsyncData(null);
      return true;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return false;
    }
  }
}

final expenseMutationControllerProvider = AsyncNotifierProvider<ExpenseMutationController, void>(
  ExpenseMutationController.new,
);
