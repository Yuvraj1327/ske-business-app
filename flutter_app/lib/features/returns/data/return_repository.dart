import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/return_models.dart';

class ReturnRepository {
  ReturnRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SalesReturn> createReturn({
    required String saleId,
    required List<({String saleItemId, double quantity})> items,
    String? reason,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/returns',
      data: {
        'sale_id': saleId,
        'items': items.map((i) => {'sale_item_id': i.saleItemId, 'quantity': i.quantity.toString()}).toList(),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return SalesReturn.fromJson(response.data!);
  }

  Future<Page<SalesReturn>> listReturns({int page = 1, int pageSize = 20, String? customerId, String? saleId}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/returns',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (customerId != null) 'customer_id': customerId,
        if (saleId != null) 'sale_id': saleId,
      },
    );
    return Page.fromJson(response.data!, SalesReturn.fromJson);
  }
}
