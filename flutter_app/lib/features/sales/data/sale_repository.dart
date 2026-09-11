import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/sale_models.dart';

class SaleRepository {
  SaleRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Sale> createSale({
    required String customerId,
    required List<DraftSaleItem> items,
    double discountAmount = 0,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/sales',
      data: {
        'customer_id': customerId,
        'discount_amount': discountAmount.toStringAsFixed(2),
        'items': items
            .map((i) => {
                  'product_id': i.productId,
                  'quantity': i.quantity.toString(),
                  'unit_price': i.unitPrice.toStringAsFixed(2),
                  'line_discount': i.lineDiscount.toStringAsFixed(2),
                })
            .toList(),
      },
    );
    return Sale.fromJson(response.data!);
  }

  Future<Page<SaleListItem>> listSales({
    int page = 1,
    int pageSize = 20,
    String? customerId,
    String? status,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/sales',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (customerId != null) 'customer_id': customerId,
        if (status != null) 'status': status,
      },
    );
    return Page.fromJson(response.data!, SaleListItem.fromJson);
  }

  Future<Sale> getSale(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/sales/$id');
    return Sale.fromJson(response.data!);
  }

  Future<Sale> cancelSale(String id) async {
    final response = await _apiClient.patch<Map<String, dynamic>>('/sales/$id/cancel');
    return Sale.fromJson(response.data!);
  }
}
