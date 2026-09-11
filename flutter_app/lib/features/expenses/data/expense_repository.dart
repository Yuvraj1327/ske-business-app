import '../../../core/network/api_client.dart';
import '../domain/expense_models.dart';

class ExpensePage {
  final List<Expense> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final double totalAmount;

  const ExpensePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalAmount,
  });

  factory ExpensePage.fromJson(Map<String, dynamic> json) {
    return ExpensePage(
      items: (json['items'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
      totalAmount: double.parse(json['total_amount'] as String),
    );
  }

  bool get hasNextPage => page < totalPages;
}

class ExpenseRepository {
  ExpenseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ExpenseCategory>> listCategories() async {
    final response = await _apiClient.get<List<dynamic>>('/expenses/categories');
    return response.data!.map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ExpenseCategory> createCategory(String name) async {
    final response = await _apiClient.post<Map<String, dynamic>>('/expenses/categories', data: {'name': name});
    return ExpenseCategory.fromJson(response.data!);
  }

  Future<ExpensePage> listExpenses({int page = 1, int pageSize = 20, String? categoryId, String? status}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/expenses',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (categoryId != null) 'category_id': categoryId,
        if (status != null) 'status': status,
      },
    );
    return ExpensePage.fromJson(response.data!);
  }

  Future<Expense> createExpense({
    required String categoryId,
    required double amount,
    DateTime? expenseDate,
    String? description,
    String? paymentMethod,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/expenses',
      data: {
        'category_id': categoryId,
        'amount': amount.toStringAsFixed(2),
        if (expenseDate != null) 'expense_date': _formatDate(expenseDate),
        if (description != null && description.isNotEmpty) 'description': description,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      },
    );
    return Expense.fromJson(response.data!);
  }

  Future<Expense> updateExpense({
    required String id,
    String? categoryId,
    double? amount,
    DateTime? expenseDate,
    String? description,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/expenses/$id',
      data: {
        if (categoryId != null) 'category_id': categoryId,
        if (amount != null) 'amount': amount.toStringAsFixed(2),
        if (expenseDate != null) 'expense_date': _formatDate(expenseDate),
        if (description != null) 'description': description,
      },
    );
    return Expense.fromJson(response.data!);
  }

  Future<Expense> voidExpense(String id) async {
    final response = await _apiClient.patch<Map<String, dynamic>>('/expenses/$id/void');
    return Expense.fromJson(response.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
