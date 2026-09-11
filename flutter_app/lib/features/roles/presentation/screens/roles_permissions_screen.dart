import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../domain/role_models.dart';
import '../providers/role_providers.dart';

/// Admin-only screen for managing role -> permission assignments. Adding a
/// brand new role type is a data change (via Supabase), not a code change —
/// this screen only manages which permissions an *existing* role has.
class RolesPermissionsScreen extends ConsumerStatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  ConsumerState<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends ConsumerState<RolesPermissionsScreen> {
  AppRole? _selectedRole;
  Set<String> _pendingPermissionKeys = {};
  bool _isSaving = false;

  void _selectRole(AppRole role) {
    setState(() {
      _selectedRole = role;
      _pendingPermissionKeys = role.permissionKeys.toSet();
    });
  }

  Future<void> _save(List<AppPermission> allPermissions) async {
    if (_selectedRole == null) return;
    setState(() => _isSaving = true);

    final permissionIds = allPermissions
        .where((p) => _pendingPermissionKeys.contains(p.key))
        .map((p) => p.id)
        .toList();

    try {
      final repo = ref.read(roleRepositoryProvider);
      final updated = await repo.updateRolePermissions(_selectedRole!.id, permissionIds);
      ref.invalidate(rolesListProvider);
      if (!mounted) return;
      setState(() {
        _selectedRole = updated;
        _pendingPermissionKeys = updated.permissionKeys.toSet();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permissions updated for ${Formatters.roleLabel(updated.name)}')),
      );
    } catch (e) {
      final failure = e is Failure ? e : Failure.unknown(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesListProvider);
    final permissionsAsync = ref.watch(permissionsListProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: rolesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(rolesListProvider),
        ),
        data: (roles) {
          _selectedRole ??= roles.isNotEmpty ? roles.first : null;
          if (_selectedRole != null && _pendingPermissionKeys.isEmpty && _selectedRole!.permissionKeys.isNotEmpty) {
            _pendingPermissionKeys = _selectedRole!.permissionKeys.toSet();
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: roles
                        .map(
                          (role) => ListTile(
                            title: Text(Formatters.roleLabel(role.name)),
                            subtitle: Text('${role.permissionKeys.length} permissions'),
                            selected: _selectedRole?.id == role.id,
                            selectedTileColor: AppColors.primary.withOpacity(0.08),
                            onTap: () => _selectRole(role),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: permissionsAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
                  data: (permissions) {
                    if (_selectedRole == null) {
                      return const Center(child: Text('No roles found.'));
                    }
                    final byModule = <String, List<AppPermission>>{};
                    for (final p in permissions) {
                      byModule.putIfAbsent(p.module, () => []).add(p);
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Permissions for ${Formatters.roleLabel(_selectedRole!.name)}', style: AppTextStyles.heading2),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : () => _save(permissions),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Save Changes'),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Expanded(
                              child: ListView(
                                children: byModule.entries.map((entry) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                                        child: Text(
                                          entry.key.toUpperCase(),
                                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      ...entry.value.map(
                                        (perm) => CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity: ListTileControlAffinity.leading,
                                          title: Text(perm.key),
                                          subtitle: perm.description != null ? Text(perm.description!) : null,
                                          value: _pendingPermissionKeys.contains(perm.key),
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                _pendingPermissionKeys.add(perm.key);
                                              } else {
                                                _pendingPermissionKeys.remove(perm.key);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
