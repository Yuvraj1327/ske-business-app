import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../network/api_client.dart';

/// Single shared Dio-based client for all repositories.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

/// Raw Supabase auth state stream — emits on sign-in, sign-out, token refresh.
/// Router guards watch this to decide whether to show the login screen.
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The resolved app-domain user (role + permissions), fetched from FastAPI's
/// /auth/me. This is null while logged out, and re-fetched whenever the
/// Supabase session changes (login, token refresh, logout).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(supabaseAuthStateProvider).valueOrNull;
  final repo = ref.watch(authRepositoryProvider);

  if (authState?.session == null && !repo.isLoggedIn) {
    return null;
  }

  return repo.fetchCurrentUser();
});
