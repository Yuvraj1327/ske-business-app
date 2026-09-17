import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/report_providers.dart';

enum _ReportKind { sales, customers, payments, outstanding, expenses, salesmen, transactions }

/// A single Reports Hub covering all 7 report types, switchable via the top
/// selector, sharing one date-range filter (where applicable — Customer and
/// Outstanding reports are point-in-time snapshots, so the range control is
/// hidden for those). Every number here comes straight from the backend's
/// aggregation queries — nothing is summed client-side.
class ReportsHubScreen extends ConsumerStatefulWidget {
  const ReportsHubScreen({super.key});

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen> {
  _ReportKind _selected = _ReportKind.sales;

  static const _labels = {
    _ReportKind.sales: 'Sales',
    _ReportKind.customers: 'Customers',
    _ReportKind.payments: 'Payments',
    _ReportKind.outstanding: 'Outstanding',
    _ReportKind.expenses: 'Expenses',
    _ReportKind.salesmen: 'Salesmen',
    _ReportKind.transactions: 'Transactions',
  };

  bool get _showsDateRange => _selected != _ReportKind.customers && _selected != _ReportKind.outstanding;

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportRangeProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reports', style: AppTextStyles.heading1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ReportKind.values
                .map((kind) => ChoiceChip(
                      label: Text(_labels[kind]!),
                      selected: _selected == kind,
                      onSelected: (_) => setState(() => _selected = kind),
                    ))
                .toList(),
          ),
          if (_showsDateRange) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _rangeChip('Today', 'today', range),
                _rangeChip('This Week', 'week', range),
                _rangeChip('This Month', 'month', range),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: _buildReportBody()),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, String value, String current) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => ref.read(reportRangeProvider.notifier).state = value,
    );
  }

  Widget _buildReportBody() {
    switch (_selected) {
      case _ReportKind.sales:
        return _SalesReportView();
      case _ReportKind.customers:
        return _CustomerReportView();
      case _ReportKind.payments:
        return _BreakdownReportView(provider: paymentReportProvider, extractBreakdown: (r) => r.breakdown);
      case _ReportKind.outstanding:
        return _OutstandingReportView();
      case _ReportKind.expenses:
        return _BreakdownReportView(provider: expenseReportProvider, extractBreakdown: (r) => r.breakdown);
      case _ReportKind.salesmen:
        return _SalesmanReportView();
      case _ReportKind.transactions:
        return _TransactionReportView();
    }
  }
}

class _SalesReportView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(salesReportProvider);
    return reportAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (report) {
        if (report.items.isEmpty) return const EmptyStateView(message: 'No sales in this range.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(context, [
              _summaryStat('Sales', '${report.totalSalesCount}'),
              _summaryStat('Total', Formatters.currency(report.totalSalesAmount)),
              _summaryStat('Discount', Formatters.currency(report.totalDiscount)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: report.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = report.items[i];
                  return ListTile(
                    title: Text(s.customerName, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${s.invoiceNumber ?? 'No invoice'} · ${Formatters.date(s.saleDate)}', overflow: TextOverflow.ellipsis),
                    trailing: Text(Formatters.currency(s.totalAmount)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CustomerReportView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(customerReportProvider);
    return reportAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (rows) {
        if (rows.isEmpty) return const EmptyStateView(message: 'No customers yet.');
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = rows[i];
            return ListTile(
              title: Text(row.customerName, overflow: TextOverflow.ellipsis),
              subtitle: Text('${row.salesCount} sale(s)'),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Formatters.currency(row.salesTotal), style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
                  if (row.outstanding > 0)
                    Text(
                      'Owes ${Formatters.currency(row.outstanding)}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BreakdownReportView extends ConsumerWidget {
  const _BreakdownReportView({required this.provider, required this.extractBreakdown});

  final ProviderListenable provider;
  final List Function(dynamic report) extractBreakdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(provider) as AsyncValue;
    return reportAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (report) {
        final breakdown = extractBreakdown(report);
        if (breakdown.isEmpty) return const EmptyStateView(message: 'No data in this range.');
        return ListView.separated(
          itemCount: breakdown.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = breakdown[i];
            return ListTile(
              title: Text(row.label.toString().replaceAll('_', ' ').toUpperCase(), overflow: TextOverflow.ellipsis),
              subtitle: Text('${row.count} entries'),
              trailing: Text(Formatters.currency(row.total), style: AppTextStyles.heading3),
            );
          },
        );
      },
    );
  }
}

class _OutstandingReportView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(outstandingReportProvider);
    return reportAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (report) {
        if (report.items.isEmpty) return const EmptyStateView(message: 'No outstanding balances. 🎉');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(context, [_summaryStat('Total Outstanding', Formatters.currency(report.grandTotal))]),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: report.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final row = report.items[i];
                  return ListTile(
                    title: Text(row.customerName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(row.phone ?? '—'),
                    trailing: Text(Formatters.currency(row.outstanding), style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SalesmanReportView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(salesmanReportProvider);
    return reportAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (rows) {
        if (rows.isEmpty) return const EmptyStateView(message: 'No salesmen yet.');
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = rows[i];
            return ListTile(
              title: Text(row.salesmanName, overflow: TextOverflow.ellipsis),
              subtitle: Text('${row.customersCount} customers · ${row.salesCount} sales', overflow: TextOverflow.ellipsis),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Formatters.currency(row.salesTotal), overflow: TextOverflow.ellipsis),
                  Text(
                    'Outstanding: ${Formatters.currency(row.outstandingTotal)}',
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TransactionReportView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(transactionReportProvider);
    return reportAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (report) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(context, [
              _summaryStat('In', Formatters.currency(report.totalIn)),
              _summaryStat('Out', Formatters.currency(report.totalOut)),
              _summaryStat('Net', Formatters.currency(report.net)),
            ]),
            const SizedBox(height: 12),
            if (report.breakdown.isEmpty)
              const Expanded(child: EmptyStateView(message: 'No transactions in this range.'))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: report.breakdown.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final row = report.breakdown[i];
                    return ListTile(
                      title: Text(row.label.toUpperCase(), overflow: TextOverflow.ellipsis),
                      trailing: Text(Formatters.currency(row.total)),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _summaryRow(BuildContext context, List<Widget> stats) {
  return Card(
    color: context.subtleSurface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [for (final stat in stats) Expanded(child: stat)]),
    ),
  );
}

Widget _summaryStat(String label, String value) {
  return Column(
    children: [
      Text(label, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis, maxLines: 1),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis, maxLines: 1),
    ],
  );
}
