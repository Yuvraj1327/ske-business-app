import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/user_repository.dart';
import '../../domain/managed_user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});

class UsersFilter extends Equatable {
  final String search;
  final String? roleId;
  final bool? isActive;
  final int page;

  const UsersFilter({this.search = '', this.roleId, this.isActive, this.page = 1});

  UsersFilter copyWith({String? search, String? roleId, bool? isActive, int? page, bool clearRole = false}) {
    return UsersFilter(
      search: search ?? this.search,
      roleId: clearRole ? null : (roleId ?? this.roleId),
      isActive: isActive ?? this.isActive,
      page: page ?? this.page,
    );
  }

  @override
  List<Object?> get props => [search, roleId, isActive, page];
}

final usersFilterProvider = StateProvider.autoDispose<UsersFilter>((ref) => const UsersFilter());

final usersListProvider = FutureProvider.autoDispose<Page<ManagedUser>>((ref) {
  final filter = ref.watch(usersFilterProvider);
  final repo = ref.watch(userRepositoryProvider);
  return repo.listUsers(
    page: filter.page,
    search: filter.search,
    roleId: filter.roleId,
    isActive: filter.isActive,
  );
});

/// Handles create/update/activate/deactivate mutations and refreshes the list.
class UserMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  UserRepository get _repo => ref.read(userRepositoryProvider);

  Future<bool> createUser({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required String roleId,
  }) => _run(() => _repo.createUser(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        roleId: roleId,
      ));

  Future<bool> updateUser({
    required String userId,
    String? fullName,
    String? phone,
    String? roleId,
  }) => _run(() => _repo.updateUser(userId: userId, fullName: fullName, phone: phone, roleId: roleId));

  Future<bool> setActive(String userId, bool isActive) => _run(() => _repo.setActive(userId, isActive));

  Future<bool> _run(Future<ManagedUser> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(usersListProvider);
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

final userMutationControllerProvider = AsyncNotifierProvider<UserMutationController, void>(
  UserMutationController.new,
);
