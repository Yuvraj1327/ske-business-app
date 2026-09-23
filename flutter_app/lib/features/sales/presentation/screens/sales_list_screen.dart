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
import '../../../../core/widgets/status_badge.dart';
import '../providers/sale_providers.dart';

class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.statusPaid;
      case 'partial':
        return AppColors.statusPartial;
      default:
        return AppColors.statusUnpaid;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesListProvider);
    final filter = ref.watch(salesFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Sales', style: AppTextStyles.heading1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Sale'),
                onPressed: () => context.go('/sales/new'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: salesAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(salesListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(message: 'No sales yet.', icon: Icons.point_of_sale_outlined);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final sale = page.items[index];
                          return ListTile(
                            title: Text(sale.customerName, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${sale.invoiceNumber ?? 'No invoice'} · ${Formatters.date(sale.saleDate)}'
                              '${sale.status == 'cancelled' ? ' · Cancelled' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Formatters.currency(sale.totalAmount), style: AppTextStyles.body),
                                const SizedBox(height: 4),
                                StatusBadge(label: sale.paymentStatus, color: _statusColor(sale.paymentStatus)),
                              ],
                            ),
                            onTap: () => context.go('/sales/${sale.id}'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${page.total} sale(s) · Page ${page.page} of ${page.totalPages}',
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
                                  ? () => ref.read(salesFilterProvider.notifier).state = filter.copyWith(page: page.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page.hasNextPage
                                  ? () => ref.read(salesFilterProvider.notifier).state = filter.copyWith(page: page.page + 1)
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
