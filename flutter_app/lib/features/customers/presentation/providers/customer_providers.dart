import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer_models.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(apiClientProvider));
});

class CustomersFilter extends Equatable {
  final String search;
  final int page;

  const CustomersFilter({this.search = '', this.page = 1});

  CustomersFilter copyWith({String? search, int? page}) =>
      CustomersFilter(search: search ?? this.search, page: page ?? this.page);

  @override
  List<Object?> get props => [search, page];
}

final customersFilterProvider = StateProvider.autoDispose<CustomersFilter>((ref) => const CustomersFilter());

final customersListProvider = FutureProvider.autoDispose<Page<Customer>>((ref) {
  final filter = ref.watch(customersFilterProvider);
  final repo = ref.watch(customerRepositoryProvider);
  return repo.listCustomers(page: filter.page, search: filter.search);
});

final customerDetailProvider = FutureProvider.autoDispose.family<Customer, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getCustomer(id);
});

final customerOutstandingProvider = FutureProvider.autoDispose.family<CustomerOutstanding, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getOutstanding(id);
});

final customerLedgerProvider = FutureProvider.autoDispose.family<CustomerLedger, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getLedger(id);
});

class CustomerMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  CustomerRepository get _repo => ref.read(customerRepositoryProvider);

  Future<bool> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.createCustomer(name: name, phone: phone, email: email, address: address, gstNumber: gstNumber);
      ref.invalidate(customersListProvider);
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

  Future<bool> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    bool? isActive,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.updateCustomer(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        gstNumber: gstNumber,
        isActive: isActive,
      );
      ref.invalidate(customersListProvider);
      ref.invalidate(customerDetailProvider(id));
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

final customerMutationControllerProvider = AsyncNotifierProvider<CustomerMutationController, void>(
  CustomerMutationController.new,
);
