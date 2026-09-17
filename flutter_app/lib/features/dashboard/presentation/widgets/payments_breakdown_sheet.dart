import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../reports/domain/report_models.dart';
import '../../../reports/presentation/providers/report_providers.dart';

/// Tapping "Payments Received" on the dashboard opens this — a breakdown of
/// how that total splits by collection method (Cash / UPI / Bank Transfer /
/// Cheque), reusing the EXISTING `GET /reports/payments` breakdown (same
/// data Reports → Payments already shows) rather than a new endpoint, plus
/// the dashboard's own already-fetched Outstanding figure shown alongside
/// as the "not yet collected" complement — since an amount marked Credit
/// during delivery collection never becomes a Payment row (see
/// picklist_service.py), it shows up here as Outstanding, not as a
/// collection-method entry.
Future<void> showPaymentsBreakdownSheet(
  BuildContext context, {
  required String rangeKey,
  DateTime? customFrom,
  DateTime? customTo,
  required double outstandingTotal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _PaymentsBreakdownSheet(
      rangeKey: rangeKey,
      customFrom: customFrom,
      customTo: customTo,
      outstandingTotal: outstandingTotal,
    ),
  );
}

class _PaymentsBreakdownSheet extends ConsumerWidget {
  const _PaymentsBreakdownSheet({
    required this.rangeKey,
    this.customFrom,
    this.customTo,
    required this.outstandingTotal,
  });

  final String rangeKey;
  final DateTime? customFrom;
  final DateTime? customTo;
  final double outstandingTotal;

  Color _methodColor(String label) {
    switch (label.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'upi':
      case 'bank_transfer':
        return AppColors.info;
      case 'cheque':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _methodLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'upi':
        return 'UPI (Online)';
      case 'bank_transfer':
        return 'Bank Transfer (Online)';
      case 'cash':
        return 'Cash';
      case 'cheque':
        return 'Cheque';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(
      paymentBreakdownForRangeProvider((rangeKey: rangeKey, from: customFrom, to: customTo)),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Payments Received — Breakdown', style: AppTextStyles.heading2),
            const SizedBox(height: 4),
            Text('How much came in by each collection method', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 16),
            reportAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: LoadingView()),
              error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
              data: (report) {
                final breakdown = report.breakdown;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (breakdown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No payments collected in this range.', style: AppTextStyles.bodySecondary),
                      )
                    else
                      ...breakdown.map(
                        (row) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: _methodColor(row.label), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_methodLabel(row.label), style: AppTextStyles.body)),
                              Text('${row.count} · ${Formatters.currency(row.total)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Credit / Not yet collected', style: AppTextStyles.body),
                        ),
                        Text(
                          Formatters.currency(outstandingTotal),
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This is the current total outstanding across all active sales — not limited to the '
                      'selected date range, since an unpaid balance isn\'t tied to when it was created.',
                      style: AppTextStyles.caption,
                    ),
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
