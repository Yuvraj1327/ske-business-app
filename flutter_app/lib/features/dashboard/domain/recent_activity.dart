import 'package:equatable/equatable.dart';

enum RecentActivityType { sale, payment }

/// A single row in the dashboard's "Recent Activity" list — built by
/// merging the already-existing Sales and Payments list endpoints
/// client-side (see recentActivityProvider), not a dedicated backend
/// endpoint. [status] is the raw backend value (sale: unpaid/partial/paid,
/// payment: pending/cleared/cancelled) — presentation maps it to a label/color.
class RecentActivityItem extends Equatable {
  final RecentActivityType type;
  final String customerName;
  final double amount;
  final DateTime date;
  final String status;

  const RecentActivityItem({
    required this.type,
    required this.customerName,
    required this.amount,
    required this.date,
    required this.status,
  });

  @override
  List<Object?> get props => [type, customerName, amount, date, status];
}
