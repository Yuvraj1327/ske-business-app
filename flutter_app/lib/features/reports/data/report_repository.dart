import '../../../core/network/api_client.dart';
import '../domain/report_models.dart';

class ReportRepository {
  ReportRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SalesReport> getSalesReport({String range = 'month'}) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/reports/sales', queryParameters: {'range': range, 'page_size': 50});
    return SalesReport.fromJson(response.data!);
  }

  Future<List<CustomerReportRow>> getCustomerReport() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/reports/customers', queryParameters: {'page_size': 100});
    return (response.data!['items'] as List).map((e) => CustomerReportRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaymentReport> getPaymentReport({String range = 'month', DateTime? from, DateTime? to}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/reports/payments',
      queryParameters: {
        'range': range,
        'page_size': 1,
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );
    return PaymentReport.fromJson(response.data!);
  }

  Future<OutstandingReport> getOutstandingReport() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/reports/outstanding', queryParameters: {'page_size': 100});
    return OutstandingReport.fromJson(response.data!);
  }

  Future<ExpenseReport> getExpenseReport({String range = 'month'}) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/reports/expenses', queryParameters: {'range': range, 'page_size': 1});
    return ExpenseReport.fromJson(response.data!);
  }

  Future<List<SalesmanReportRow>> getSalesmanReport({String range = 'month'}) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/reports/salesmen', queryParameters: {'range': range});
    return (response.data!['items'] as List).map((e) => SalesmanReportRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TransactionReport> getTransactionReport({String range = 'month'}) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/reports/transactions', queryParameters: {'range': range});
    return TransactionReport.fromJson(response.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
