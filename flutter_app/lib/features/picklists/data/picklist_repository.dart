import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/picklist_models.dart';

class PicklistRepository {
  PicklistRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Page<Picklist>> listPicklists({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/picklists',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return Page.fromJson(response.data!, Picklist.fromJson);
  }

  Future<PicklistDetail> getPicklist(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/picklists/$id');
    return PicklistDetail.fromJson(response.data!);
  }

  /// [chequeAmount] is required by the backend when [status] is 'cheque',
  /// [salesmanId] when it is 'credit'.
  Future<PicklistItem> confirmItem(String itemId, String status, {double? chequeAmount, String? salesmanId}) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/picklists/items/$itemId/confirm',
      data: {
        'status': status,
        if (chequeAmount != null) 'cheque_amount': chequeAmount.toStringAsFixed(2),
        if (salesmanId != null) 'salesman_id': salesmanId,
      },
    );
    return PicklistItem.fromJson(response.data!);
  }
}
