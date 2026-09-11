import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dashboard_summary.dart';
import '../providers/dashboard_providers.dart';

class DashboardDateFilterBar extends ConsumerWidget {
  const DashboardDateFilterBar({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked == null) return;
    ref.read(dashboardFilterProvider.notifier).state = DashboardFilter(
      range: DashboardDateRange.custom,
      customFrom: picked.start,
      customTo: picked.end,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);

    Widget chip(String label, DashboardDateRange range) {
      final selected = filter.range == range;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            if (range == DashboardDateRange.custom) {
              _pickCustomRange(context, ref);
            } else {
              ref.read(dashboardFilterProvider.notifier).state = DashboardFilter(range: range);
            }
          },
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('Today', DashboardDateRange.today),
        chip('This Week', DashboardDateRange.week),
        chip('This Month', DashboardDateRange.month),
        chip('Custom', DashboardDateRange.custom),
      ],
    );
  }
}
