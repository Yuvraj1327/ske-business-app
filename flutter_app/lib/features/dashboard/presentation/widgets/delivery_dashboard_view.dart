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
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import 'summary_card.dart';

/// Delivery-focused landing view for the Delivery Agent role — deliberately
/// NOT the KPI dashboard (GET /dashboard/summary), because that endpoint
/// reports company-wide totals (all customers, all sales revenue, etc.)
/// with no per-user scoping, which would leak business-wide financial data
/// to a role that should only ever see their own assigned work.
///
/// Instead this reuses the ALREADY row-scoped `customersListProvider` and
/// `salesListProvider` — the backend restricts both to records assigned to
/// the current user whenever they hold `*.view_assigned` (rather than
/// `*.view_all`), which a Delivery Agent does by design (see
/// database/migrations/002_add_delivery_agent_role.sql). No new backend
/// endpoint was needed for this.
class DeliveryDashboardView extends ConsumerWidget {
  const DeliveryDashboardView({super.key});

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
    final customersAsync = ref.watch(customersListProvider);
    final salesAsync = ref.watch(salesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                label: 'My Customers',
                value: customersAsync.valueOrNull?.total.toString() ?? '—',
                icon: Icons.people_alt_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                label: 'My Deliveries',
                value: salesAsync.valueOrNull?.total.toString() ?? '—',
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Assigned Deliveries', style: AppTextStyles.heading3),
        const SizedBox(height: 8),
        salesAsync.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: LoadingView()),
          error: (e, _) => ErrorView(
            failure: e is Failure ? e : Failure.unknown(e.toString()),
            onRetry: () => ref.invalidate(salesListProvider),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const EmptyStateView(
                message: 'No deliveries assigned to you yet.',
                icon: Icons.local_shipping_outlined,
              );
            }
            return Column(
              children: page.items
                  .map(
                    (sale) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(sale.customerName),
                        subtitle: Text('${sale.invoiceNumber ?? 'No invoice'} · ${Formatters.date(sale.saleDate)}'),
                        trailing: StatusBadge(label: sale.paymentStatus, color: _statusColor(sale.paymentStatus)),
                        onTap: () => context.go('/sales/${sale.id}'),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
