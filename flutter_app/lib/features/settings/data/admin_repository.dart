import '../../../core/network/api_client.dart';

/// Admin-only maintenance actions. Currently just Reset Data — kept in the
/// Settings feature (rather than a standalone "admin" feature) since that's
/// the only place it's triggered from.
class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Calls POST /admin/reset-data. The backend verifies [password] against
  /// Supabase Auth BEFORE deleting anything — a wrong password surfaces as
  /// a normal [Failure] (via the API client's existing error mapping,
  /// typically 401) and nothing is touched. Returns the success message on
  /// completion.
  Future<String> resetData(String password) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/admin/reset-data',
      data: {'password': password},
    );
    return response.data!['message'] as String;
  }
}
