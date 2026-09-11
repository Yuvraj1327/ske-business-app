import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/managed_user.dart';

class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Page<ManagedUser>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? roleId,
    bool? isActive,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/users',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        if (roleId != null) 'role_id': roleId,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Page.fromJson(response.data!, ManagedUser.fromJson);
  }

  Future<ManagedUser> createUser({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required String roleId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/users',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'role_id': roleId,
      },
    );
    return ManagedUser.fromJson(response.data!);
  }

  Future<ManagedUser> updateUser({
    required String userId,
    String? fullName,
    String? phone,
    String? roleId,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/users/$userId',
      data: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (roleId != null) 'role_id': roleId,
      },
    );
    return ManagedUser.fromJson(response.data!);
  }

  Future<ManagedUser> setActive(String userId, bool isActive) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/users/$userId/${isActive ? 'activate' : 'deactivate'}',
    );
    return ManagedUser.fromJson(response.data!);
  }
}
