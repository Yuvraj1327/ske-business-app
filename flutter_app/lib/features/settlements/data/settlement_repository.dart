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
    required List<String> salesmanIds,
    String? notes,
    String? pickSheetNo,
    double pickSheetValue = 0,
    double returnsAmount = 0,
    double damageReturnAmount = 0,
    double discountAmount = 0,
    double cashAmount = 0,
    double onlineAmount = 0,
    double chequeAmount = 0,
    double creditBillsAmount = 0,
    double oldShortAmount = 0,
    List<DraftSettlementRow> items = const [],
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/settlements',
      data: {
        'sheet_date': _formatDate(sheetDate),
        'delivery_agent_id': deliveryAgentId,
        'salesman_ids': salesmanIds,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (pickSheetNo != null && pickSheetNo.isNotEmpty) 'pick_sheet_no': pickSheetNo,
        'pick_sheet_value': pickSheetValue.toStringAsFixed(2),
        'returns_amount': returnsAmount.toStringAsFixed(2),
        'damage_return_amount': damageReturnAmount.toStringAsFixed(2),
        'discount_amount': discountAmount.toStringAsFixed(2),
        'cash_amount': cashAmount.toStringAsFixed(2),
        'online_amount': onlineAmount.toStringAsFixed(2),
        'cheque_amount': chequeAmount.toStringAsFixed(2),
        'credit_bills_amount': creditBillsAmount.toStringAsFixed(2),
        'old_short_amount': oldShortAmount.toStringAsFixed(2),
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

  /// Admin-only partial update to a sheet's header/general fields. Only the
  /// provided (non-null) fields are sent, so callers can update just one
  /// field at a time.
  Future<SettlementSheetDetail> updateSheet(
    String sheetId, {
    DateTime? sheetDate,
    String? deliveryAgentId,
    List<String>? salesmanIds,
    String? notes,
    String? pickSheetNo,
    double? pickSheetValue,
    double? returnsAmount,
    double? damageReturnAmount,
    double? discountAmount,
    double? cashAmount,
    double? onlineAmount,
    double? chequeAmount,
    double? creditBillsAmount,
    double? oldShortAmount,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/settlements/$sheetId',
      data: {
        if (sheetDate != null) 'sheet_date': _formatDate(sheetDate),
        if (deliveryAgentId != null) 'delivery_agent_id': deliveryAgentId,
        if (salesmanIds != null) 'salesman_ids': salesmanIds,
        if (notes != null) 'notes': notes,
        if (pickSheetNo != null) 'pick_sheet_no': pickSheetNo,
        if (pickSheetValue != null) 'pick_sheet_value': pickSheetValue.toStringAsFixed(2),
        if (returnsAmount != null) 'returns_amount': returnsAmount.toStringAsFixed(2),
        if (damageReturnAmount != null) 'damage_return_amount': damageReturnAmount.toStringAsFixed(2),
        if (discountAmount != null) 'discount_amount': discountAmount.toStringAsFixed(2),
        if (cashAmount != null) 'cash_amount': cashAmount.toStringAsFixed(2),
        if (onlineAmount != null) 'online_amount': onlineAmount.toStringAsFixed(2),
        if (chequeAmount != null) 'cheque_amount': chequeAmount.toStringAsFixed(2),
        if (creditBillsAmount != null) 'credit_bills_amount': creditBillsAmount.toStringAsFixed(2),
        if (oldShortAmount != null) 'old_short_amount': oldShortAmount.toStringAsFixed(2),
      },
    );
    return SettlementSheetDetail.fromJson(response.data!);
  }

  /// Add one customer row to an already-existing sheet — the assigned
  /// Delivery Agent's (or Admin's) way to add customers after creation,
  /// since rows are optional at creation time.
  Future<SettlementSheetItem> addItem(
    String sheetId, {
    required String customerId,
    required double invoiceAmount,
    required double creditAmount,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/settlements/$sheetId/items',
      data: {
        'customer_id': customerId,
        'invoice_amount': invoiceAmount.toStringAsFixed(2),
        'credit_amount': creditAmount.toStringAsFixed(2),
      },
    );
    return SettlementSheetItem.fromJson(response.data!);
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
    required double cashAmount,
    required double onlineAmount,
    required double chequeAmount,
    required double creditAmount,
    String? agentNotes,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/settlements/items/$itemId/delivery',
      data: {
        'delivery_status': deliveryStatus,
        'cash_amount': cashAmount.toStringAsFixed(2),
        'online_amount': onlineAmount.toStringAsFixed(2),
        'cheque_amount': chequeAmount.toStringAsFixed(2),
        'credit_amount': creditAmount.toStringAsFixed(2),
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
