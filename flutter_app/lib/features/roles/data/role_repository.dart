import '../../../core/network/api_client.dart';
import '../domain/role_models.dart';

class RoleRepository {
  RoleRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppRole>> listRoles() async {
    final response = await _apiClient.get<List<dynamic>>('/roles');
    return response.data!.map((e) => AppRole.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AppPermission>> listPermissions() async {
    final response = await _apiClient.get<List<dynamic>>('/permissions');
    return response.data!.map((e) => AppPermission.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppRole> updateRolePermissions(String roleId, List<String> permissionIds) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/roles/$roleId/permissions',
      data: {'permission_ids': permissionIds},
    );
    return AppRole.fromJson(response.data!);
  }
}
