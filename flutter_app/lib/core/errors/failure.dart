import 'package:equatable/equatable.dart';

/// Unified failure type surfaced to the UI layer. Every repository method
/// that can fail should resolve to this (never let raw DioException or
/// PostgrestException leak into providers/widgets).
class Failure extends Equatable {
  final String code;
  final String message;
  final String? field;

  const Failure({required this.code, required this.message, this.field});

  factory Failure.network() => const Failure(
        code: 'NETWORK_ERROR',
        message: 'Could not reach the server. Check your internet connection.',
      );

  factory Failure.unauthorized() => const Failure(
        code: 'UNAUTHORIZED',
        message: 'Your session has expired. Please log in again.',
      );

  factory Failure.unknown([String? detail]) => Failure(
        code: 'UNKNOWN_ERROR',
        message: detail ?? 'Something went wrong. Please try again.',
      );

  @override
  List<Object?> get props => [code, message, field];
}
