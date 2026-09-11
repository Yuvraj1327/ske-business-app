import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/payment_repository.dart';
import '../../domain/payment_models.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

class PaymentsFilter extends Equatable {
  final String? customerId;
  final String? status;
  final int page;

  const PaymentsFilter({this.customerId, this.status, this.page = 1});

  PaymentsFilter copyWith({String? customerId, String? status, int? page}) => PaymentsFilter(
        customerId: customerId ?? this.customerId,
        status: status ?? this.status,
        page: page ?? this.page,
      );

  @override
  List<Object?> get props => [customerId, status, page];
}

final paymentsFilterProvider = StateProvider.autoDispose<PaymentsFilter>((ref) => const PaymentsFilter());

final paymentsListProvider = FutureProvider.autoDispose<Page<Payment>>((ref) {
  final filter = ref.watch(paymentsFilterProvider);
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.listPayments(page: filter.page, customerId: filter.customerId, status: filter.status);
});

/// Payments for a single customer's detail page (Payment History tab).
final customerPaymentsProvider = FutureProvider.autoDispose.family<Page<Payment>, String>((ref, customerId) {
  return ref.watch(paymentRepositoryProvider).listPayments(customerId: customerId, pageSize: 50);
});

/// Pending cheques awaiting clear/bounce — used by the Cheque Tracker view.
final pendingChequesProvider = FutureProvider.autoDispose<Page<Payment>>((ref) {
  return ref.watch(paymentRepositoryProvider).listPayments(paymentMethod: 'cheque', status: 'pending', pageSize: 50);
});

class PaymentMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Payment?> createPayment({
    required String customerId,
    String? saleId,
    required double amount,
    required String paymentMethod,
    String? notes,
    String? chequeNumber,
    DateTime? chequeDate,
    String? bankName,
  }) async {
    state = const AsyncLoading();
    try {
      final payment = await ref.read(paymentRepositoryProvider).createPayment(
            customerId: customerId,
            saleId: saleId,
            amount: amount,
            paymentMethod: paymentMethod,
            notes: notes,
            chequeNumber: chequeNumber,
            chequeDate: chequeDate,
            bankName: bankName,
          );
      ref.invalidate(paymentsListProvider);
      ref.invalidate(pendingChequesProvider);
      state = const AsyncData(null);
      return payment;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }

  Future<bool> updateChequeStatus(String paymentId, String status) async {
    state = const AsyncLoading();
    try {
      await ref.read(paymentRepositoryProvider).updateChequeStatus(paymentId, status);
      ref.invalidate(paymentsListProvider);
      ref.invalidate(pendingChequesProvider);
      state = const AsyncData(null);
      return true;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return false;
    }
  }
}

final paymentMutationControllerProvider = AsyncNotifierProvider<PaymentMutationController, void>(
  PaymentMutationController.new,
);
