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

  // IMPORTANT: always prefer the backend's own error envelope when present.
  // The backend (see app/core/security.py) returns *specific* 401 reasons —
  // invalid/expired token, no matching app profile, or a deactivated
  // account — each with a distinct, actionable message. Short-circuiting on
  // statusCode == 401 here (as a previous version of this file did) threw
  // that specific reason away and replaced it with a generic "session
  // expired" message for every 401, which made real failures (e.g. a user
  // whose Supabase Auth account has no matching `users` row) look like an
  // ordinary expired-token case and impossible to debug from the UI.
  if (data is Map && data['error'] is Map) {
    final errorMap = data['error'] as Map;
    return Failure(
      code: (errorMap['code'] as String?) ?? 'UNKNOWN_ERROR',
      message: (errorMap['message'] as String?) ?? 'Something went wrong.',
      field: errorMap['field'] as String?,
    );
  }

  // No structured body from the backend (e.g. the request never reached
  // FastAPI at all) — fall back to a generic message per status code.
  if (statusCode == 401) {
    return Failure.unauthorized();
  }

  return Failure.unknown(e.message);
}
