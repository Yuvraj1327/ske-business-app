import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared_models/page.dart';
import '../domain/import_models.dart';

class ImportRepository {
  ImportRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Uploads the file and returns immediately with a 'queued' job — actual
  /// parsing happens server-side in a background task. Poll [getJob] for
  /// progress, or just re-fetch [listJobs].
  Future<ImportJob> uploadFile({
    required String entityType,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'entity_type': entityType,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final response = await _apiClient.post<Map<String, dynamic>>('/imports/upload', data: formData);
    return ImportJob.fromJson(response.data!);
  }

  Future<Page<ImportJob>> listJobs({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/imports', queryParameters: {'page': page, 'page_size': pageSize});
    return Page.fromJson(response.data!, ImportJob.fromJson);
  }

  Future<ImportJob> getJob(String jobId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/imports/$jobId');
    return ImportJob.fromJson(response.data!);
  }

  Future<Page<ImportJobRow>> getJobRows(String jobId, {String? status}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/imports/$jobId/rows',
      queryParameters: {'page_size': 100, if (status != null) 'status': status},
    );
    return Page.fromJson(response.data!, ImportJobRow.fromJson);
  }
}
