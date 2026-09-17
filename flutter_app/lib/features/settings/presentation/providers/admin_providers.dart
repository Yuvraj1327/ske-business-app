import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

class ResetDataController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the success message on completion, or null on failure (in
  /// which case `state` carries the Failure — typically "incorrect
  /// password" for a 401 — for the caller to display). No reset happens
  /// server-side unless this returns non-null.
  Future<String?> resetData(String password) async {
    state = const AsyncLoading();
    try {
      final message = await ref.read(adminRepositoryProvider).resetData(password);
      state = const AsyncData(null);
      return message;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }
}

final resetDataControllerProvider = AsyncNotifierProvider<ResetDataController, void>(
  ResetDataController.new,
);
