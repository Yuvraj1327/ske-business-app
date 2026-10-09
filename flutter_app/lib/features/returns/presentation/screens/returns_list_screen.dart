import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/return_providers.dart';

class ReturnsListScreen extends ConsumerWidget {
  const ReturnsListScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final result = await ref.read(returnExportControllerProvider.notifier).exportXlsx();
    switch (result) {
      case ReturnExportResult.saved:
        messenger.showSnackBar(const SnackBar(content: Text('Sales returns exported.')));
      case ReturnExportResult.failed:
        final error = ref.read(returnExportControllerProvider).error;
        final message = error is Failure ? error.message : 'Could not export sales returns. Please try again.';
        messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: errorColor));
      case ReturnExportResult.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsListProvider);
    final filter = ref.watch(returnsFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Sales Returns', style: AppTextStyles.heading1)),
              AppButton(
                label: 'Export XLSX',
                icon: Icons.download_outlined,
                expand: false,
                isLoading: ref.watch(returnExportControllerProvider).isLoading,
                // Nothing to export while loading, on error, or when empty.
                onPressed: (returnsAsync.valueOrNull?.total ?? 0) > 0 ? () => _export(context, ref) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: returnsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(returnsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(message: 'No returns recorded yet.', icon: Icons.assignment_return_outlined);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final ret = page.items[index];
                          return ListTile(
                            title: Text(ret.customerName, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${Formatters.date(ret.returnDate)}${ret.reason != null ? ' · ${ret.reason}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(Formatters.currency(ret.totalReturnAmount)),
                            onTap: () => context.push('/sales/${ret.saleId}'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${page.total} return(s) · Page ${page.page} of ${page.totalPages}',
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
                                  ? () => ref.read(returnsFilterProvider.notifier).state =
                                      filter.copyWith(page: page.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page.hasNextPage
                                  ? () => ref.read(returnsFilterProvider.notifier).state =
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
