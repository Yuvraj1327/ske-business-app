import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../payments/presentation/providers/payment_providers.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_summary.dart';
import '../../domain/recent_activity.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

class DashboardFilter extends Equatable {
  final DashboardDateRange range;
  final DateTime? customFrom;
  final DateTime? customTo;

  const DashboardFilter({this.range = DashboardDateRange.today, this.customFrom, this.customTo});

  DashboardFilter copyWith({DashboardDateRange? range, DateTime? customFrom, DateTime? customTo}) {
    return DashboardFilter(
      range: range ?? this.range,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
    );
  }

  @override
  List<Object?> get props => [range, customFrom, customTo];
}

final dashboardFilterProvider = StateProvider.autoDispose<DashboardFilter>((ref) => const DashboardFilter());

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getSummary(range: filter.range, from: filter.customFrom, to: filter.customTo);
});

/// Merges the 5 most recent sales and 5 most recent payments (both already
/// most-recent-first server-side) into one list for the dashboard's
/// "Recent Activity" section — no new backend endpoint, reuses the same
/// repositories/providers as the Sales and Payments list screens.
final recentActivityProvider = FutureProvider.autoDispose<List<RecentActivityItem>>((ref) async {
  final salesFuture = ref.watch(saleRepositoryProvider).listSales(pageSize: 5);
  final paymentsFuture = ref.watch(paymentRepositoryProvider).listPayments(pageSize: 5);
  final salePage = await salesFuture;
  final paymentPage = await paymentsFuture;

  final items = <RecentActivityItem>[
    for (final sale in salePage.items)
      RecentActivityItem(
        type: RecentActivityType.sale,
        customerName: sale.customerName,
        amount: sale.totalAmount,
        date: sale.saleDate,
        status: sale.paymentStatus,
      ),
    for (final payment in paymentPage.items)
      RecentActivityItem(
        type: RecentActivityType.payment,
        customerName: payment.customerName,
        amount: payment.amount,
        date: payment.paymentDate,
        status: payment.status,
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));

  return items.take(5).toList();
});
