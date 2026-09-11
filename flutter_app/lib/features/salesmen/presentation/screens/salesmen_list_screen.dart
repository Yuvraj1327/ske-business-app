import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/salesman_providers.dart';

class SalesmenListScreen extends ConsumerWidget {
  const SalesmenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesmenAsync = ref.watch(salesmenListProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Salesmen', style: AppTextStyles.heading1),
          const SizedBox(height: 16),
          Expanded(
            child: salesmenAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(salesmenListProvider),
              ),
              data: (salesmen) {
                if (salesmen.isEmpty) {
                  return const EmptyStateView(
                    message: 'No salesmen yet. Create a user with the "salesman" role from the Users screen.',
                    icon: Icons.badge_outlined,
                  );
                }
                return ListView.separated(
                  itemCount: salesmen.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final salesman = salesmen[index];
                    return ListTile(
                      title: Text(salesman.fullName),
                      subtitle: Text(salesman.phone ?? '—'),
                      trailing: StatusBadge(
                        label: salesman.isActive ? 'Active' : 'Inactive',
                        color: salesman.isActive ? AppColors.success : AppColors.statusCancelled,
                      ),
                      onTap: () => context.go('/salesmen/${salesman.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
