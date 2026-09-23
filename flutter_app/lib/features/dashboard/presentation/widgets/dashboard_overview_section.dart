import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/dashboard_summary.dart';

/// Compact "Overview" card — four independently-labeled meters (Sales,
/// Payments Received, Outstanding, Expenses), each a proportional bar
/// against the largest of the four. Purely a client-side presentation of
/// [DashboardSummary] fields already fetched for the KPI cards above; no
/// extra API call. Each row carries its own icon + label + value, so color
/// reinforces category rather than being the only way to tell rows apart.
class DashboardOverviewSection extends StatelessWidget {
  const DashboardOverviewSection({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _OverviewRow(label: 'Sales', value: summary.salesTotal, icon: Icons.point_of_sale_outlined, color: AppColors.primary),
      _OverviewRow(label: 'Payments Received', value: summary.paymentsReceived, icon: Icons.payments_outlined, color: AppColors.success),
      _OverviewRow(label: 'Outstanding', value: summary.outstandingTotal, icon: Icons.hourglass_bottom_outlined, color: AppColors.warning),
      _OverviewRow(label: 'Expenses', value: summary.expensesTotal, icon: Icons.receipt_long_outlined, color: AppColors.error),
    ];
    final maxValue = rows.map((r) => r.value).fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview', style: AppTextStyles.heading3),
            const SizedBox(height: 14),
            for (var i = 0; i < rows.length; i++) ...[
              _buildRow(context, rows[i], maxValue),
              if (i != rows.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _OverviewRow row, double maxValue) {
    final fraction = maxValue <= 0 ? 0.0 : (row.value / maxValue).clamp(0.0, 1.0);
    final trackColor = Theme.of(context).dividerColor.withOpacity(0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(row.icon, size: 15, color: row.color),
            const SizedBox(width: 6),
            Expanded(child: Text(row.label, style: AppTextStyles.bodySecondary)),
            Text(Formatters.currency(row.value), style: AppTextStyles.amount.copyWith(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 6, width: constraints.maxWidth, color: trackColor),
                  Container(height: 6, width: constraints.maxWidth * fraction, color: row.color),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverviewRow {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _OverviewRow({required this.label, required this.value, required this.icon, required this.color});
}
