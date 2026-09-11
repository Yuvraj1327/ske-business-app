import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Payment> createPayment({
    required String customerId,
    String? saleId,
    required double amount,
    required String paymentMethod,
    String? notes,
    String? chequeNumber,
    DateTime? chequeDate,
    String? bankName,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/payments',
      data: {
        'customer_id': customerId,
        if (saleId != null) 'sale_id': saleId,
        'amount': amount.toStringAsFixed(2),
        'payment_method': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (chequeNumber != null) 'cheque_number': chequeNumber,
        if (chequeDate != null) 'cheque_date': _formatDate(chequeDate),
        if (bankName != null) 'bank_name': bankName,
      },
    );
    return Payment.fromJson(response.data!);
  }

  Future<Page<Payment>> listPayments({
    int page = 1,
    int pageSize = 20,
    String? customerId,
    String? saleId,
    String? paymentMethod,
    String? status,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/payments',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (customerId != null) 'customer_id': customerId,
        if (saleId != null) 'sale_id': saleId,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (status != null) 'status': status,
      },
    );
    return Page.fromJson(response.data!, Payment.fromJson);
  }

  Future<Payment> updateChequeStatus(String paymentId, String status) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/payments/$paymentId/status',
      data: {'status': status},
    );
    return Payment.fromJson(response.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
