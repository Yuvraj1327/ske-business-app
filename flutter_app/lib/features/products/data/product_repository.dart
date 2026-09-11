import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/product_models.dart';

class ProductRepository {
  ProductRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Page<Product>> listProducts({int page = 1, int pageSize = 20, String? search, bool? isActive}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/products',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Page.fromJson(response.data!, Product.fromJson);
  }

  Future<Product> createProduct({required String name, String? sku, String unit = 'pcs', required double defaultPrice}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/products',
      data: {
        'name': name,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        'unit': unit,
        'default_price': defaultPrice.toStringAsFixed(2),
      },
    );
    return Product.fromJson(response.data!);
  }

  Future<Product> updateProduct({
    required String id,
    String? name,
    String? sku,
    String? unit,
    double? defaultPrice,
    bool? isActive,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/products/$id',
      data: {
        if (name != null) 'name': name,
        if (sku != null) 'sku': sku,
        if (unit != null) 'unit': unit,
        if (defaultPrice != null) 'default_price': defaultPrice.toStringAsFixed(2),
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Product.fromJson(response.data!);
  }
}
