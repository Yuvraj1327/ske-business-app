import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/picklist_providers.dart';

/// Admin sees every picklist; a Delivery Agent sees only their own — same
/// screen, same query, the backend does the scoping (see
/// PicklistService.list_picklists). This is the "clean table/column-based
/// view, not a raw Excel file" the Delivery Agent role needs.
class PicklistsListScreen extends ConsumerWidget {
  const PicklistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picklistsAsync = ref.watch(picklistsListProvider);
    final filter = ref.watch(picklistsFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Picklists', style: AppTextStyles.heading1),
          const SizedBox(height: 16),
          Expanded(
            child: picklistsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(picklistsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(
                    message: 'No picklists yet. Admin can import one from Excel Import.',
                    icon: Icons.checklist_rtl_outlined,
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final picklist = page.items[i];
                          final counts = picklist.counts;
                          final allDone = counts.pending == 0;
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => context.go('/picklists/${picklist.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(picklist.picklistNo, style: AppTextStyles.heading3),
                                        ),
                                        Text(Formatters.currency(picklist.totalAmount), style: AppTextStyles.amount),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${picklist.deliveryAgentName}${picklist.psrRoute != null ? ' · ${picklist.psrRoute}' : ''}',
                                      style: AppTextStyles.bodySecondary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _countChip('${counts.total} deliveries', AppColors.textSecondary),
                                        if (counts.pending > 0) _countChip('${counts.pending} pending', AppColors.warning),
                                        if (counts.cash > 0) _countChip('${counts.cash} cash', AppColors.success),
                                        if (counts.online > 0) _countChip('${counts.online} online', AppColors.success),
                                        if (counts.credit > 0) _countChip('${counts.credit} credit', AppColors.error),
                                        if (allDone) _countChip('All confirmed', AppColors.success),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
                            '${page.total} picklist(s) · Page ${page.page} of ${page.totalPages}',
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
                                  ? () => ref.read(picklistsFilterProvider.notifier).state =
                                      filter.copyWith(page: page.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page.hasNextPage
                                  ? () => ref.read(picklistsFilterProvider.notifier).state =
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

  Widget _countChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
