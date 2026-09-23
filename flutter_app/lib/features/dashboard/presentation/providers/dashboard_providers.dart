import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_summary.dart';

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
