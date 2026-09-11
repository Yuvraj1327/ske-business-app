/// Centralized endpoint paths (relative to API_BASE_URL). Keeping these in
/// one place means a backend route rename only needs one edit here.
class ApiEndpoints {
  ApiEndpoints._();

  static const String me = '/auth/me';
  static const String health = '/health';

  // Populated as later build steps add features:
  // static const String customers = '/customers';
  // static const String sales = '/sales';
  // static const String dashboardSummary = '/dashboard/summary';
}
