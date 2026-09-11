import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/customer_models.dart';

class CustomerRepository {
  CustomerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Page<Customer>> listCustomers({int page = 1, int pageSize = 20, String? search, bool? isActive}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/customers',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Page.fromJson(response.data!, Customer.fromJson);
  }

  Future<Customer> getCustomer(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/customers/$id');
    return Customer.fromJson(response.data!);
  }

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    String? assignedSalesmanId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/customers',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (address != null && address.isNotEmpty) 'address': address,
        if (gstNumber != null && gstNumber.isNotEmpty) 'gst_number': gstNumber,
        if (assignedSalesmanId != null) 'assigned_salesman_id': assignedSalesmanId,
      },
    );
    return Customer.fromJson(response.data!);
  }

  Future<Customer> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    bool? isActive,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/customers/$id',
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (gstNumber != null) 'gst_number': gstNumber,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Customer.fromJson(response.data!);
  }

  Future<CustomerOutstanding> getOutstanding(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/customers/$id/outstanding');
    return CustomerOutstanding.fromJson(response.data!);
  }

  Future<CustomerLedger> getLedger(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/customers/$id/ledger');
    return CustomerLedger.fromJson(response.data!);
  }
}
