import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/permission.dart';
import '../../../../core/permissions/permission_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import '../../domain/dashboard_summary.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_date_filter_bar.dart';
import '../widgets/delivery_dashboard_view.dart';
import '../widgets/payments_breakdown_sheet.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/summary_card.dart';

/// The dashboard branches by role:
///  - Delivery Agent gets a delivery-focused view (see
///    DeliveryDashboardView) built entirely from already row-scoped
///    customer/sales data — it deliberately never calls
///    GET /dashboard/summary, which reports company-wide totals with no
///    per-user scoping and would leak business financials to a role that
///    should only see its own assigned work.
///  - Admin and Salesman keep the date-filtered KPI dashboard, backed by
///    GET /dashboard/summary — all totals/counts are computed server-side
///    per the "don't calculate important numbers only on Flutter"
///    requirement.
/// The top bar (title + settings) is provided by AppShell.
class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    if (userAsync.isLoading) {
      return const LoadingView(message: 'Loading your profile...');
    }

    final user = userAsync.valueOrNull;
    if (user == null) {
      return const LoadingView();
    }

    final isDeliveryAgent = user.roleName == 'delivery_agent';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(fullName: user.fullName, roleName: user.roleName),
          const SizedBox(height: 14),
          if (isDeliveryAgent) const DeliveryDashboardView() else const _BusinessDashboardView(),
        ],
      ),
    );
  }
}

/// Compact welcome banner — a single lightly-tinted card rather than bare
/// text, so the header reads as a deliberate piece of the page instead of
/// a leftover title. Brand navy used sparingly here (a 6%-opacity tint),
/// consistent with "use brand colors selectively, not everywhere."
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.fullName, required this.roleName});

  final String fullName;
  final String roleName;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,', style: AppTextStyles.bodySecondary),
                Text(fullName, style: AppTextStyles.heading1.copyWith(fontSize: 22)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
            child: Text(
              Formatters.roleLabel(roleName),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The KPI dashboard (Admin/Salesman): quick actions, date-filtered summary
/// cards, and a Recent Activity list — all built from data already fetched
/// elsewhere in the app (GET /dashboard/summary and the same sales list the
/// Sales screen uses), no new endpoints.
class _BusinessDashboardView extends ConsumerWidget {
  const _BusinessDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QuickActionsRow(),
        const SizedBox(height: 18),
        const DashboardDateFilterBar(),
        const SizedBox(height: 12),
        summaryAsync.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 40), child: LoadingView()),
          error: (e, _) => ErrorView(
            failure: e is Failure ? e : Failure.unknown(e.toString()),
            onRetry: () => ref.invalidate(dashboardSummaryProvider),
          ),
          data: (summary) {
            final cards = [
              SummaryCard(
                label: 'Total Customers',
                value: '${summary.totalCustomers}',
                icon: Icons.people_outline,
              ),
              SummaryCard(
                label: 'Sales (${summary.salesCount})',
                value: Formatters.currency(summary.salesTotal),
                icon: Icons.point_of_sale_outlined,
                subtitle: '${Formatters.date(summary.rangeStart)} – ${Formatters.date(summary.rangeEnd)}',
              ),
              SummaryCard(
                label: 'Payments Received',
                value: Formatters.currency(summary.paymentsReceived),
                icon: Icons.payments_outlined,
                iconColor: AppColors.success,
                onTap: () {
                  final filter = ref.read(dashboardFilterProvider);
                  final rangeKey = switch (filter.range) {
                    DashboardDateRange.today => 'today',
                    DashboardDateRange.week => 'week',
                    DashboardDateRange.month => 'month',
                    DashboardDateRange.custom => 'custom',
                  };
                  showPaymentsBreakdownSheet(
                    context,
                    rangeKey: rangeKey,
                    customFrom: filter.customFrom,
                    customTo: filter.customTo,
                    outstandingTotal: summary.outstandingTotal,
                  );
                },
              ),
              SummaryCard(
                label: 'Expenses',
                value: Formatters.currency(summary.expensesTotal),
                icon: Icons.receipt_long_outlined,
                iconColor: AppColors.error,
              ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 640
                        ? 2
                        : 2; // even on narrow phones, a 2-up grid reads more
                            // compact than a tall single column of tiles.

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SummaryCard(
                      label: 'Outstanding',
                      value: Formatters.currency(summary.outstandingTotal),
                      icon: Icons.hourglass_bottom_outlined,
                      iconColor: AppColors.warning,
                      subtitle: 'Across all active sales',
                      isHero: true,
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: crossAxisCount == 4 ? 1.7 : 1.35,
                      children: cards,
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        const _RecentActivitySection(),
      ],
    );
  }
}

/// Frequently-used actions, permission-gated exactly like the rest of the
/// app — reuses existing routes/dialogs rather than adding new ones.
class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreateSale = ref.watch(hasPermissionProvider(Permission.salesCreate));
    final canRecordPayment = ref.watch(hasPermissionProvider(Permission.paymentsCreate));
    final canCreateCustomer = ref.watch(hasPermissionProvider(Permission.customersCreate));

    final actions = <Widget>[
      if (canCreateSale)
        QuickActionButton(label: 'New Sale', icon: Icons.point_of_sale_outlined, onTap: () => context.go('/sales/new')),
      if (canRecordPayment)
        QuickActionButton(label: 'Record Payment', icon: Icons.payments_outlined, onTap: () => context.go('/payments/new')),
      if (canCreateCustomer)
        QuickActionButton(label: 'Add Customer', icon: Icons.person_add_alt_1_outlined, onTap: () => showCustomerFormDialog(context)),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

/// The most recent sales, reusing the exact same `salesListProvider` the
/// Sales screen uses (default filters = most recent first, all statuses) —
/// no new backend endpoint.
class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Activity', style: AppTextStyles.heading3),
            TextButton(onPressed: () => context.go('/sales'), child: const Text('View all')),
          ],
        ),
        salesAsync.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingView()),
          error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
          data: (page) {
            final recent = page.items.take(5).toList();
            if (recent.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: EmptyStateView(message: 'No sales yet.', icon: Icons.receipt_long_outlined),
              );
            }
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      dense: true,
                      title: Text(recent[i].customerName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${recent[i].invoiceNumber ?? 'No invoice'} · ${Formatters.date(recent[i].saleDate)}',
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Formatters.currency(recent[i].totalAmount), style: AppTextStyles.body),
                          const SizedBox(height: 2),
                          StatusBadge(label: recent[i].paymentStatus, color: _statusColor(recent[i].paymentStatus)),
                        ],
                      ),
                      onTap: () => context.go('/sales/${recent[i].id}'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
