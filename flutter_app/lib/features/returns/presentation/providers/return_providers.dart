import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/return_repository.dart';
import '../../domain/return_models.dart';

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  return ReturnRepository(ref.watch(apiClientProvider));
});

class ReturnsFilter extends Equatable {
  final int page;

  const ReturnsFilter({this.page = 1});

  ReturnsFilter copyWith({int? page}) => ReturnsFilter(page: page ?? this.page);

  @override
  List<Object?> get props => [page];
}

final returnsFilterProvider = StateProvider.autoDispose<ReturnsFilter>((ref) => const ReturnsFilter());

final returnsListProvider = FutureProvider.autoDispose<Page<SalesReturn>>((ref) {
  final filter = ref.watch(returnsFilterProvider);
  return ref.watch(returnRepositoryProvider).listReturns(page: filter.page);
});

/// Returns for a single sale — used to show what's already been returned
/// when computing "returnable" quantity in the Create Return screen.
final saleReturnsProvider = FutureProvider.autoDispose.family<Page<SalesReturn>, String>((ref, saleId) {
  return ref.watch(returnRepositoryProvider).listReturns(saleId: saleId, pageSize: 50);
});

class ReturnMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<SalesReturn?> createReturn({
    required String saleId,
    required List<({String saleItemId, double quantity})> items,
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(returnRepositoryProvider).createReturn(saleId: saleId, items: items, reason: reason);
      ref.invalidate(returnsListProvider);
      ref.invalidate(saleReturnsProvider(saleId));
      state = const AsyncData(null);
      return result;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }
}

final returnMutationControllerProvider = AsyncNotifierProvider<ReturnMutationController, void>(
  ReturnMutationController.new,
);
