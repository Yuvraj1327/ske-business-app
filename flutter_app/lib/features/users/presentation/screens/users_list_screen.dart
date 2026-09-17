import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/managed_user.dart';
import '../providers/user_providers.dart';
import '../widgets/user_form_dialog.dart';

class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(ManagedUser user) async {
    final action = user.isActive ? 'deactivate' : 'activate';
    final confirmed = await showConfirmDialog(
      context,
      title: '${action[0].toUpperCase()}${action.substring(1)} ${user.fullName}?',
      message: user.isActive
          ? 'They will no longer be able to log in until reactivated.'
          : 'They will be able to log in again.',
      confirmLabel: action[0].toUpperCase() + action.substring(1),
      isDestructive: user.isActive,
    );
    if (!confirmed) return;

    final success = await ref.read(userMutationControllerProvider.notifier).setActive(user.id, !user.isActive);
    if (!mounted) return;
    if (!success) {
      final state = ref.read(userMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final filter = ref.watch(usersFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Users', style: AppTextStyles.heading1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add User'),
                onPressed: () => showUserFormDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by name or phone...',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              ref.read(usersFilterProvider.notifier).state = filter.copyWith(search: value, page: 1);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: usersAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(usersListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(message: 'No users found.', icon: Icons.people_outline);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = page.items[index];
                          return ListTile(
                            title: Text(user.fullName, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${Formatters.roleLabel(user.roleName)}${user.phone != null ? ' · ${user.phone}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(
                                  label: user.isActive ? 'Active' : 'Inactive',
                                  color: user.isActive ? AppColors.success : AppColors.statusCancelled,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => showUserFormDialog(context, existingUser: user),
                                ),
                                IconButton(
                                  icon: Icon(
                                    user.isActive ? Icons.block : Icons.check_circle_outline,
                                    size: 20,
                                    color: user.isActive ? AppColors.error : AppColors.success,
                                  ),
                                  onPressed: () => _toggleActive(user),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${page.total} user(s) · Page ${page.page} of ${page.totalPages}',
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: page.page > 1
                                  ? () => ref.read(usersFilterProvider.notifier).state =
                                      filter.copyWith(page: page.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page.hasNextPage
                                  ? () => ref.read(usersFilterProvider.notifier).state =
                                      filter.copyWith(page: page.page + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
