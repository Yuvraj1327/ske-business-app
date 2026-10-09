import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_config.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio that:
///  - points at the FastAPI backend (never Supabase directly for business data)
///  - attaches the current Supabase session's access token to every request
///  - normalizes errors into [Failure] via [mapDioErrorToFailure]
///
/// Repositories depend on this, never on Dio directly, so swapping the HTTP
/// client later only touches this file.
class ApiClient {
  ApiClient() : dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (DioException e, handler) {
          // Centralized place to react to 401s globally if needed (e.g.
          // force sign-out). Individual repositories still get a mapped
          // Failure via mapDioErrorToFailure for local handling.
          handler.next(e);
        },
      ),
    );
  }

  final Dio dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw mapDioErrorToFailure(e);
    }
  }

  /// GET a binary body (e.g. a generated .xlsx). Error bodies also arrive as
  /// bytes, so they're decoded back to the backend's JSON error envelope
  /// before mapping to a [Failure].
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 120)),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is List<int>) {
        try {
          e.response!.data = jsonDecode(utf8.decode(body));
        } catch (_) {
          // Not JSON — fall through with the raw error.
        }
      }
      throw mapDioErrorToFailure(e);
    }
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    try {
      return await dio.post<T>(path, data: data);
    } on DioException catch (e) {
      throw mapDioErrorToFailure(e);
    }
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) async {
    try {
      return await dio.patch<T>(path, data: data);
    } on DioException catch (e) {
      throw mapDioErrorToFailure(e);
    }
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    try {
      return await dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw mapDioErrorToFailure(e);
    }
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    try {
      return await dio.delete<T>(path, data: data);
    } on DioException catch (e) {
      throw mapDioErrorToFailure(e);
    }
  }
}
