import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(apiClientProvider));
});

class TransactionsFilter extends Equatable {
  final String? transactionType; // cash | upi | bank | null (all)
  final String? direction;
  final int page;

  const TransactionsFilter({this.transactionType, this.direction, this.page = 1});

  TransactionsFilter copyWith({String? transactionType, bool clearType = false, String? direction, int? page}) =>
      TransactionsFilter(
        transactionType: clearType ? null : (transactionType ?? this.transactionType),
        direction: direction ?? this.direction,
        page: page ?? this.page,
      );

  @override
  List<Object?> get props => [transactionType, direction, page];
}

final transactionsFilterProvider = StateProvider.autoDispose<TransactionsFilter>((ref) => const TransactionsFilter());

final transactionsListProvider = FutureProvider.autoDispose<TransactionPage>((ref) {
  final filter = ref.watch(transactionsFilterProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.listTransactions(page: filter.page, transactionType: filter.transactionType, direction: filter.direction);
});

class TransactionMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createTransaction({
    required String transactionType,
    required String direction,
    required double amount,
    String? referenceNote,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(transactionRepositoryProvider).createTransaction(
            transactionType: transactionType,
            direction: direction,
            amount: amount,
            referenceNote: referenceNote,
          );
      ref.invalidate(transactionsListProvider);
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

final transactionMutationControllerProvider = AsyncNotifierProvider<TransactionMutationController, void>(
  TransactionMutationController.new,
);
