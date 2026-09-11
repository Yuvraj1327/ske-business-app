import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../data/role_repository.dart';
import '../../domain/role_models.dart';

final roleRepositoryProvider = Provider<RoleRepository>((ref) {
  return RoleRepository(ref.watch(apiClientProvider));
});

final rolesListProvider = FutureProvider.autoDispose<List<AppRole>>((ref) {
  return ref.watch(roleRepositoryProvider).listRoles();
});

final permissionsListProvider = FutureProvider.autoDispose<List<AppPermission>>((ref) {
  return ref.watch(roleRepositoryProvider).listPermissions();
});
