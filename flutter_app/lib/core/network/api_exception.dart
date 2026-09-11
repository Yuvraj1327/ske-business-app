import 'package:dio/dio.dart';

import '../errors/failure.dart';

/// Maps the backend's error envelope:
///   { "error": { "code": "...", "message": "...", "field": "..." } }
/// (see FastAPI's app/core/exception_handlers.py) into a [Failure].
Failure mapDioErrorToFailure(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return Failure.network();
  }

  final statusCode = e.response?.statusCode;
  final data = e.response?.data;

  if (statusCode == 401) {
    return Failure.unauthorized();
  }

  if (data is Map && data['error'] is Map) {
    final errorMap = data['error'] as Map;
    return Failure(
      code: (errorMap['code'] as String?) ?? 'UNKNOWN_ERROR',
      message: (errorMap['message'] as String?) ?? 'Something went wrong.',
      field: errorMap['field'] as String?,
    );
  }

  return Failure.unknown(e.message);
}
