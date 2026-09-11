import '../../../core/network/api_client.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummary> getSummary({
    required DashboardDateRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final rangeKey = switch (range) {
      DashboardDateRange.today => 'today',
      DashboardDateRange.week => 'week',
      DashboardDateRange.month => 'month',
      DashboardDateRange.custom => 'custom',
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/dashboard/summary',
      queryParameters: {
        'range': rangeKey,
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );
    return DashboardSummary.fromJson(response.data!);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
