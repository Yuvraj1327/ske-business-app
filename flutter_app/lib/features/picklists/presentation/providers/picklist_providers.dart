import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../../roles/domain/role_models.dart';
import '../../../roles/presentation/providers/role_providers.dart';
import '../../../users/domain/managed_user.dart';
import '../../../users/presentation/providers/user_providers.dart';
import '../../data/picklist_repository.dart';
import '../../domain/picklist_models.dart';

final picklistRepositoryProvider = Provider<PicklistRepository>((ref) {
  return PicklistRepository(ref.watch(apiClientProvider));
});

/// The Delivery Agent picker for the "upload picklist" flow — reuses the
/// EXISTING GET /roles (to resolve the 'delivery_agent' role's id) and
/// GET /users (filtered by that role, active only) endpoints. No new
/// backend endpoint was added for this; it's the same mechanism the Users
/// screen's role dropdown already uses, just consumed the other way
/// around (find users by role, rather than list roles for a user).
final deliveryAgentsProvider = FutureProvider.autoDispose<List<ManagedUser>>((ref) async {
  final roles = await ref.watch(rolesListProvider.future);
  AppRole? deliveryAgentRole;
  for (final r in roles) {
    if (r.name == 'delivery_agent') {
      deliveryAgentRole = r;
      break;
    }
  }
  if (deliveryAgentRole == null) return [];

  final page = await ref.watch(userRepositoryProvider).listUsers(
        pageSize: 100,
        roleId: deliveryAgentRole.id,
        isActive: true,
      );
  return page.items;
});

class PicklistsFilter extends Equatable {
  final int page;

  const PicklistsFilter({this.page = 1});

  PicklistsFilter copyWith({int? page}) => PicklistsFilter(page: page ?? this.page);

  @override
  List<Object?> get props => [page];
}

final picklistsFilterProvider = StateProvider.autoDispose<PicklistsFilter>((ref) => const PicklistsFilter());

/// Admin sees every picklist; a Delivery Agent sees only their own —
/// enforced server-side (see PicklistService.list_picklists), so this is
/// the same query for both roles.
final picklistsListProvider = FutureProvider.autoDispose<Page<Picklist>>((ref) {
  final filter = ref.watch(picklistsFilterProvider);
  return ref.watch(picklistRepositoryProvider).listPicklists(page: filter.page, pageSize: 50);
});

final picklistDetailProvider = FutureProvider.autoDispose.family<PicklistDetail, String>((ref, id) {
  return ref.watch(picklistRepositoryProvider).getPicklist(id);
});

class PicklistMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> confirmItem(String picklistId, String itemId, String status) async {
    state = const AsyncLoading();
    try {
      await ref.read(picklistRepositoryProvider).confirmItem(itemId, status);
      ref.invalidate(picklistDetailProvider(picklistId));
      ref.invalidate(picklistsListProvider);
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

final picklistMutationControllerProvider = AsyncNotifierProvider<PicklistMutationController, void>(
  PicklistMutationController.new,
);
