import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../../customers/domain/customer_models.dart';
import '../domain/salesman_models.dart';

class SalesmanRepository {
  SalesmanRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Salesman>> listSalesmen() async {
    final response = await _apiClient.get<List<dynamic>>('/salesmen');
    return response.data!.map((e) => Salesman.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Page<Customer>> getSalesmanCustomers(String salesmanId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/salesmen/$salesmanId/customers', queryParameters: {'page_size': 50});
    return Page.fromJson(response.data!, Customer.fromJson);
  }

  Future<void> assignCustomer(String salesmanId, String customerId) async {
    await _apiClient.post('/salesmen/$salesmanId/assign-customer', data: {'customer_id': customerId});
  }

  Future<SalesmanPerformance> getPerformance(String salesmanId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/salesmen/$salesmanId/performance');
    return SalesmanPerformance.fromJson(response.data!);
  }

  Future<SalesTask> createTask({
    required String salesmanId,
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/salesmen/$salesmanId/tasks',
      data: {
        'assigned_to': salesmanId,
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (dueDate != null) 'due_date': _formatDate(dueDate),
      },
    );
    return SalesTask.fromJson(response.data!);
  }

  Future<Page<SalesTask>> listTasks({int page = 1, int pageSize = 20, String? assignedTo, String? status}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/tasks',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (status != null) 'status': status,
      },
    );
    return Page.fromJson(response.data!, SalesTask.fromJson);
  }

  Future<SalesTask> updateTaskStatus(String taskId, String status) async {
    final response = await _apiClient.patch<Map<String, dynamic>>('/tasks/$taskId/status', data: {'status': status});
    return SalesTask.fromJson(response.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
