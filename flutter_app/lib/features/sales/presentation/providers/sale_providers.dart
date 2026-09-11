import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/sale_repository.dart';
import '../../domain/sale_models.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(ref.watch(apiClientProvider));
});

class SalesFilter extends Equatable {
  final String? customerId;
  final String? status;
  final int page;

  const SalesFilter({this.customerId, this.status, this.page = 1});

  SalesFilter copyWith({String? customerId, String? status, int? page}) => SalesFilter(
        customerId: customerId ?? this.customerId,
        status: status ?? this.status,
        page: page ?? this.page,
      );

  @override
  List<Object?> get props => [customerId, status, page];
}

final salesFilterProvider = StateProvider.autoDispose<SalesFilter>((ref) => const SalesFilter());

final salesListProvider = FutureProvider.autoDispose<Page<SaleListItem>>((ref) {
  final filter = ref.watch(salesFilterProvider);
  final repo = ref.watch(saleRepositoryProvider);
  return repo.listSales(page: filter.page, customerId: filter.customerId, status: filter.status);
});

/// Sales for a single customer's detail page (Sales History tab) — a
/// separate provider from the main filtered list so the two don't fight
/// over pagination/filter state.
final customerSalesProvider = FutureProvider.autoDispose.family<Page<SaleListItem>, String>((ref, customerId) {
  return ref.watch(saleRepositoryProvider).listSales(customerId: customerId, pageSize: 50);
});

final saleDetailProvider = FutureProvider.autoDispose.family<Sale, String>((ref, id) {
  return ref.watch(saleRepositoryProvider).getSale(id);
});

/// Holds the in-progress line items for the Create Sale form.
class DraftSaleItemsNotifier extends Notifier<List<DraftSaleItem>> {
  @override
  List<DraftSaleItem> build() => [];

  void addItem(DraftSaleItem item) => state = [...state, item];

  void removeAt(int index) => state = [...state]..removeAt(index);

  void clear() => state = [];
}

final draftSaleItemsProvider = NotifierProvider<DraftSaleItemsNotifier, List<DraftSaleItem>>(
  DraftSaleItemsNotifier.new,
);

class SaleMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Sale?> createSale({required String customerId, required List<DraftSaleItem> items, double discountAmount = 0}) async {
    state = const AsyncLoading();
    try {
      final sale = await ref.read(saleRepositoryProvider).createSale(
            customerId: customerId,
            items: items,
            discountAmount: discountAmount,
          );
      ref.invalidate(salesListProvider);
      state = const AsyncData(null);
      return sale;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }

  Future<bool> cancelSale(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(saleRepositoryProvider).cancelSale(id);
      ref.invalidate(salesListProvider);
      ref.invalidate(saleDetailProvider(id));
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

final saleMutationControllerProvider = AsyncNotifierProvider<SaleMutationController, void>(SaleMutationController.new);
