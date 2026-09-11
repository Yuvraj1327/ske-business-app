import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../data/auth_repository.dart';

/// Holds the async state of a login attempt (idle/loading/error) so the
/// login screen can show a spinner and surface errors without touching
/// business logic directly.
class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial state to load — idle until submit() is called.
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> submit({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await _repo.signInWithPassword(email: email, password: password);
      // Force currentUserProvider to re-fetch /auth/me with the new session.
      ref.invalidate(currentUserProvider);
      state = const AsyncData(null);
      return true;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return false;
    }
  }
}

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(LoginController.new);
