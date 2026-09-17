import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/breakpoints.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/app_user.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_date_filter_bar.dart';
import '../widgets/dashboard_overview_section.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_recent_activity.dart';
import '../widgets/delivery_dashboard_view.dart';
import '../widgets/summary_card.dart';

/// The dashboard branches by role:
///  - Delivery Agent gets a delivery-focused view (see
///    DeliveryDashboardView) built entirely from already row-scoped
///    customer/sales data — it deliberately never calls
///    GET /dashboard/summary, which reports company-wide totals with no
///    per-user scoping and would leak business financials to a role that
///    should only see its own assigned work.
///  - Admin and Salesman keep the existing date-filtered KPI dashboard,
///    backed by GET /dashboard/summary — all totals/counts are computed
///    server-side per the "don't calculate important numbers only on
///    Flutter" requirement.
/// The top bar (title + settings) is provided by AppShell.
///
/// Layout note (KPI dashboard): Outstanding gets a full-width "hero"
/// treatment since it's the single most actionable figure for a trade
/// business. On narrow (mobile) widths the remaining cards stack in a plain
/// Column sized to their own content, rather than a GridView with a fixed
/// aspect ratio — a fixed ratio at one column forces each card's height to
/// (screen width ÷ ratio), which is far taller than the content needs.
class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    if (userAsync.isLoading) {
      return const LoadingView(message: 'Loading your profile...');
    }

    if (userAsync.hasError) {
      return ErrorView(
        failure: userAsync.error is Failure ? userAsync.error as Failure : Failure.unknown(userAsync.error.toString()),
        onRetry: () => ref.invalidate(currentUserProvider),
      );
    }

    final user = userAsync.valueOrNull;
    if (user == null) {
      return const LoadingView();
    }

    final isDeliveryAgent = user.roleName == 'delivery_agent';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(user: user),
          const SizedBox(height: 18),
          if (isDeliveryAgent)
            const DeliveryDashboardView()
          else
            const _BusinessDashboardView(),
        ],
      ),
    );
  }
}

/// Welcome header with a role badge — a touch more presence than a plain
/// heading, while staying compact (one row, no extra card chrome).
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, ${user.fullName}', style: AppTextStyles.heading1),
              const SizedBox(height: 4),
              Text('Here\'s what\'s happening with your business', style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            Formatters.roleLabel(user.roleName),
            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// The original KPI dashboard (Admin/Salesman) — unchanged in behavior,
/// only extracted into its own widget so DashboardShellScreen can cleanly
/// branch by role above.
class _BusinessDashboardView extends ConsumerWidget {
  const _BusinessDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardDateFilterBar(),
        const SizedBox(height: 16),
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
                // Compact 2-column grid even on mobile — a tighter, more
                // scannable layout than the old single-column stack.
                final crossAxisCount = constraints.maxWidth >= AppBreakpoints.medium ? 4 : 2;

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
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: crossAxisCount == 2 ? 1.55 : 1.7,
                      children: cards,
                    ),
                    const SizedBox(height: 20),
                    DashboardOverviewSection(summary: summary),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        Text('Quick Actions', style: AppTextStyles.heading3),
        const SizedBox(height: 10),
        const DashboardQuickActions(),
        const SizedBox(height: 20),
        const DashboardRecentActivity(),
      ],
    );
  }
}
