import 'package:equatable/equatable.dart';

/// Mirrors GET /dashboard/summary. Money fields arrive as strings (see
/// backend's app/schemas/common.py::money_str) and are parsed to double
/// only for display — the source of truth for the math is always the
/// backend, never recomputed in Flutter.
class DashboardSummary extends Equatable {
  final String rangeKey;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int totalCustomers;
  final int salesCount;
  final double salesTotal;
  final double paymentsReceived;
  final double outstandingTotal;
  final double expensesTotal;

  const DashboardSummary({
    required this.rangeKey,
    required this.rangeStart,
    required this.rangeEnd,
    required this.totalCustomers,
    required this.salesCount,
    required this.salesTotal,
    required this.paymentsReceived,
    required this.outstandingTotal,
    required this.expensesTotal,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      rangeKey: json['range_key'] as String,
      rangeStart: DateTime.parse(json['range_start'] as String),
      rangeEnd: DateTime.parse(json['range_end'] as String),
      totalCustomers: json['total_customers'] as int,
      salesCount: json['sales_count'] as int,
      salesTotal: double.parse(json['sales_total'] as String),
      paymentsReceived: double.parse(json['payments_received'] as String),
      outstandingTotal: double.parse(json['outstanding_total'] as String),
      expensesTotal: double.parse(json['expenses_total'] as String),
    );
  }

  @override
  List<Object?> get props => [
        rangeKey,
        rangeStart,
        rangeEnd,
        totalCustomers,
        salesCount,
        salesTotal,
        paymentsReceived,
        outstandingTotal,
        expensesTotal,
      ];
}

enum DashboardDateRange { today, week, month, custom }
