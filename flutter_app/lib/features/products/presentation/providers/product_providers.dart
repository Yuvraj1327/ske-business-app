import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/product_repository.dart';
import '../../domain/product_models.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(apiClientProvider));
});

class ProductsFilter extends Equatable {
  final String search;
  final int page;

  const ProductsFilter({this.search = '', this.page = 1});

  ProductsFilter copyWith({String? search, int? page}) =>
      ProductsFilter(search: search ?? this.search, page: page ?? this.page);

  @override
  List<Object?> get props => [search, page];
}

final productsFilterProvider = StateProvider.autoDispose<ProductsFilter>((ref) => const ProductsFilter());

final productsListProvider = FutureProvider.autoDispose<Page<Product>>((ref) {
  final filter = ref.watch(productsFilterProvider);
  final repo = ref.watch(productRepositoryProvider);
  return repo.listProducts(page: filter.page, search: filter.search);
});

/// Loads all active products (single page, high page_size) for pickers like
/// the "add item" dropdown in the Create Sale screen.
final activeProductsForPickerProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final page = await repo.listProducts(page: 1, pageSize: 100, isActive: true);
  return page.items;
});

class ProductMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ProductRepository get _repo => ref.read(productRepositoryProvider);

  Future<bool> createProduct({required String name, String? sku, String unit = 'pcs', required double defaultPrice}) =>
      _run(() => _repo.createProduct(name: name, sku: sku, unit: unit, defaultPrice: defaultPrice));

  Future<bool> updateProduct({
    required String id,
    String? name,
    String? sku,
    String? unit,
    double? defaultPrice,
    bool? isActive,
  }) =>
      _run(() => _repo.updateProduct(id: id, name: name, sku: sku, unit: unit, defaultPrice: defaultPrice, isActive: isActive));

  Future<bool> _run(Future<Product> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(productsListProvider);
      ref.invalidate(activeProductsForPickerProvider);
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

final productMutationControllerProvider = AsyncNotifierProvider<ProductMutationController, void>(
  ProductMutationController.new,
);
