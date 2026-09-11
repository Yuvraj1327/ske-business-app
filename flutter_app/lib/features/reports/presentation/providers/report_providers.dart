import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../data/report_repository.dart';
import '../../domain/report_models.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(apiClientProvider));
});

final reportRangeProvider = StateProvider.autoDispose<String>((ref) => 'month');

final salesReportProvider = FutureProvider.autoDispose<SalesReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportRepositoryProvider).getSalesReport(range: range);
});

final customerReportProvider = FutureProvider.autoDispose<List<CustomerReportRow>>((ref) {
  return ref.watch(reportRepositoryProvider).getCustomerReport();
});

final paymentReportProvider = FutureProvider.autoDispose<PaymentReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportRepositoryProvider).getPaymentReport(range: range);
});

final outstandingReportProvider = FutureProvider.autoDispose<OutstandingReport>((ref) {
  return ref.watch(reportRepositoryProvider).getOutstandingReport();
});

final expenseReportProvider = FutureProvider.autoDispose<ExpenseReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportRepositoryProvider).getExpenseReport(range: range);
});

final salesmanReportProvider = FutureProvider.autoDispose<List<SalesmanReportRow>>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportRepositoryProvider).getSalesmanReport(range: range);
});

final transactionReportProvider = FutureProvider.autoDispose<TransactionReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportRepositoryProvider).getTransactionReport(range: range);
});
