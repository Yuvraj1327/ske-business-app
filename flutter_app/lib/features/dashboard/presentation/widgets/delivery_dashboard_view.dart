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
import '../../../picklists/presentation/providers/picklist_providers.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import 'summary_card.dart';

/// Delivery-focused landing view for the Delivery Agent role — deliberately
/// NOT the KPI dashboard (GET /dashboard/summary), because that endpoint
/// reports company-wide totals (all customers, all sales revenue, etc.)
/// with no per-user scoping, which would leak business-wide financial data
/// to a role that should only ever see their own assigned work.
///
/// "My Picklists" is the primary section — a delivery agent's actual
/// assigned work is tracked via `Picklist.delivery_agent_id` (set when
/// Admin imports a picklist and assigns it to them), not via
/// `Sale.salesman_id` (picklist-derived sales intentionally have no
/// salesman_id, since there's no real matched salesman — see
/// picklist_service.py). The "Assigned Deliveries" section below reuses the
/// already row-scoped `salesListProvider`/`customersListProvider` from
/// before the picklist workflow existed — kept as-is for anyone who also
/// has sales/customers directly assigned to them outside the picklist flow.
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

  Color _picklistItemStatusColor(String status) {
    switch (status) {
      case 'cash':
      case 'online':
        return AppColors.success;
      case 'credit':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersListProvider);
    final salesAsync = ref.watch(salesListProvider);
    final picklistsAsync = ref.watch(picklistsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Picklists', style: AppTextStyles.heading3),
            TextButton(onPressed: () => context.go('/picklists'), child: const Text('View all')),
          ],
        ),
        picklistsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 16), child: LoadingView()),
          error: (e, _) => ErrorView(
            failure: e is Failure ? e : Failure.unknown(e.toString()),
            onRetry: () => ref.invalidate(picklistsListProvider),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: EmptyStateView(message: 'No picklists assigned to you yet.', icon: Icons.checklist_rtl_outlined),
              );
            }
            return Column(
              children: page.items.take(5).map((picklist) {
                final counts = picklist.counts;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(picklist.picklistNo),
                    subtitle: Text(
                      '${counts.total} deliveries · ${counts.pending} pending'
                      '${picklist.psrRoute != null ? ' · ${picklist.psrRoute}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: counts.pending == 0
                        ? const StatusBadge(label: 'Done', color: AppColors.success)
                        : StatusBadge(label: '${counts.pending} pending', color: AppColors.warning),
                    onTap: () => context.go('/picklists/${picklist.id}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
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
                label: 'Assigned Sales',
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
                message: 'No sales directly assigned to you outside of picklists.',
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
