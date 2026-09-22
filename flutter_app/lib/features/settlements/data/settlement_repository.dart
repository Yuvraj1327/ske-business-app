import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/settlement_models.dart';

class SettlementRepository {
  SettlementRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Page<SettlementSheet>> listSheets({int page = 1, int pageSize = 20, String? status}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/settlements',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status': status,
      },
    );
    return Page.fromJson(response.data!, SettlementSheet.fromJson);
  }

  Future<SettlementSheetDetail> getSheet(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/settlements/$id');
    return SettlementSheetDetail.fromJson(response.data!);
  }

  Future<SettlementSheetDetail> createSheet({
    required DateTime sheetDate,
    required String deliveryAgentId,
    required String salesmanId,
    String? notes,
    required List<DraftSettlementRow> items,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/settlements',
      data: {
        'sheet_date': _formatDate(sheetDate),
        'delivery_agent_id': deliveryAgentId,
        'salesman_id': salesmanId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items
            .map((row) => {
                  'customer_id': row.customerId,
                  'invoice_amount': row.invoiceAmount.toStringAsFixed(2),
                  'credit_amount': row.creditAmount.toStringAsFixed(2),
                })
            .toList(),
      },
    );
    return SettlementSheetDetail.fromJson(response.data!);
  }

  Future<SettlementSheetDetail> updateStatus(String sheetId, String status) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/settlements/$sheetId/status',
      data: {'status': status},
    );
    return SettlementSheetDetail.fromJson(response.data!);
  }

  Future<SettlementSheetItem> updateItemDelivery({
    required String itemId,
    required String deliveryStatus,
    required double amountCollected,
    required String paymentMode,
    String? agentNotes,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/settlements/items/$itemId/delivery',
      data: {
        'delivery_status': deliveryStatus,
        'amount_collected': amountCollected.toStringAsFixed(2),
        'payment_mode': paymentMode,
        if (agentNotes != null && agentNotes.isNotEmpty) 'agent_notes': agentNotes,
      },
    );
    return SettlementSheetItem.fromJson(response.data!);
  }

  Future<SettlementSheetItem> updateItemCredit({
    required String itemId,
    required double creditCollected,
    String? salesmanNotes,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/settlements/items/$itemId/credit',
      data: {
        'credit_collected': creditCollected.toStringAsFixed(2),
        if (salesmanNotes != null && salesmanNotes.isNotEmpty) 'salesman_notes': salesmanNotes,
      },
    );
    return SettlementSheetItem.fromJson(response.data!);
  }

  // Same manual zero-padded formatting as PaymentRepository._formatDate —
  // avoids any locale/timezone surprises DateFormat could introduce for a
  // plain calendar date.
  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
