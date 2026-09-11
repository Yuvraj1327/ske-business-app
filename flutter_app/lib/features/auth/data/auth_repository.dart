import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/app_user.dart';

/// Auth is split across two systems by design (see architecture doc):
///  - Supabase Auth owns credentials (sign-in/sign-out, session/JWT issuance)
///  - FastAPI owns the app-domain profile (role, permissions, active status)
///
/// This repository is the single place that talks to both.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithPassword({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      if (response.session == null) {
        throw const Failure(code: 'LOGIN_FAILED', message: 'Login failed. Please try again.');
      }
    } on AuthException catch (e) {
      throw Failure(code: 'LOGIN_FAILED', message: e.message);
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  bool get isLoggedIn => _supabase.auth.currentSession != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Fetches the caller's app-domain profile (role + permissions) from
  /// FastAPI. Called right after login, and whenever the app needs to
  /// refresh the user's permission set (e.g. after an admin changes their role).
  Future<AppUser> fetchCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.me);
    return AppUser.fromJson(response.data!);
  }
}
