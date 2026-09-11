import '../../../core/network/api_client.dart';
import '../domain/transaction_models.dart';

class TransactionPage {
  final List<AppTransaction> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final double totalIn;
  final double totalOut;

  const TransactionPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalIn,
    required this.totalOut,
  });

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    return TransactionPage(
      items: (json['items'] as List).map((e) => AppTransaction.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
      totalIn: double.parse(json['total_in'] as String),
      totalOut: double.parse(json['total_out'] as String),
    );
  }

  bool get hasNextPage => page < totalPages;
}

class TransactionRepository {
  TransactionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<TransactionPage> listTransactions({
    int page = 1,
    int pageSize = 20,
    String? transactionType,
    String? direction,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (transactionType != null) 'transaction_type': transactionType,
        if (direction != null) 'direction': direction,
      },
    );
    return TransactionPage.fromJson(response.data!);
  }

  Future<AppTransaction> createTransaction({
    required String transactionType,
    required String direction,
    required double amount,
    String? referenceNote,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/transactions',
      data: {
        'transaction_type': transactionType,
        'direction': direction,
        'amount': amount,
        if (referenceNote != null && referenceNote.isNotEmpty) 'reference_note': referenceNote,
      },
    );
    return AppTransaction.fromJson(response.data!);
  }
}
