import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/recent_activity.dart';
import '../providers/dashboard_providers.dart';

/// Most-recent 5 sales/payments combined — independent of the date filter
/// bar above it (which scopes the KPI totals), since "recent" means most
/// recent overall, not "within the selected range".
class DashboardRecentActivity extends ConsumerWidget {
  const DashboardRecentActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity', style: AppTextStyles.heading3),
            const SizedBox(height: 4),
            activityAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ErrorView(
                  failure: e is Failure ? e : Failure.unknown(e.toString()),
                  onRetry: () => ref.invalidate(recentActivityProvider),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No recent sales or payments yet.', style: AppTextStyles.bodySecondary),
                  );
                }
                return Column(
                  children: [
                    for (final item in items) _ActivityTile(item: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final RecentActivityItem item;

  (String, Color) _statusLabelAndColor() {
    if (item.type == RecentActivityType.sale) {
      switch (item.status) {
        case 'paid':
          return ('Paid', AppColors.statusPaid);
        case 'partial':
          return ('Partial', AppColors.statusPartial);
        default:
          return ('Unpaid', AppColors.statusUnpaid);
      }
    }
    switch (item.status) {
      case 'cleared':
        return ('Cleared', AppColors.success);
      case 'cancelled':
        return ('Cancelled', AppColors.statusCancelled);
      default:
        return ('Pending', AppColors.statusPending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSale = item.type == RecentActivityType.sale;
    final (statusLabel, statusColor) = _statusLabelAndColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSale ? AppColors.primary : AppColors.success).withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSale ? Icons.point_of_sale_outlined : Icons.payments_outlined,
              size: 16,
              color: isSale ? AppColors.primary : AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isSale ? 'Sale' : 'Payment'} · ${item.customerName}',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(Formatters.date(item.date), style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.currency(item.amount), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(statusLabel, style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
