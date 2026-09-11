import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../../customers/domain/customer_models.dart';
import '../../data/salesman_repository.dart';
import '../../domain/salesman_models.dart';

final salesmanRepositoryProvider = Provider<SalesmanRepository>((ref) {
  return SalesmanRepository(ref.watch(apiClientProvider));
});

final salesmenListProvider = FutureProvider.autoDispose<List<Salesman>>((ref) {
  return ref.watch(salesmanRepositoryProvider).listSalesmen();
});

final salesmanCustomersProvider = FutureProvider.autoDispose.family<Page<Customer>, String>((ref, salesmanId) {
  return ref.watch(salesmanRepositoryProvider).getSalesmanCustomers(salesmanId);
});

final salesmanPerformanceProvider = FutureProvider.autoDispose.family<SalesmanPerformance, String>((ref, salesmanId) {
  return ref.watch(salesmanRepositoryProvider).getPerformance(salesmanId);
});

/// The current user's own tasks (assigned_to defaults server-side to the
/// caller). Used for a salesman's personal task list / "My Tasks" view.
final myTasksProvider = FutureProvider.autoDispose<Page<SalesTask>>((ref) {
  return ref.watch(salesmanRepositoryProvider).listTasks(pageSize: 50);
});

final salesmanTasksProvider = FutureProvider.autoDispose.family<Page<SalesTask>, String>((ref, salesmanId) {
  return ref.watch(salesmanRepositoryProvider).listTasks(assignedTo: salesmanId, pageSize: 50);
});

class SalesmanMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  SalesmanRepository get _repo => ref.read(salesmanRepositoryProvider);

  Future<bool> assignCustomer(String salesmanId, String customerId) async {
    state = const AsyncLoading();
    try {
      await _repo.assignCustomer(salesmanId, customerId);
      ref.invalidate(salesmanCustomersProvider(salesmanId));
      ref.invalidate(salesmanPerformanceProvider(salesmanId));
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

  Future<bool> createTask({required String salesmanId, required String title, String? description, DateTime? dueDate}) async {
    state = const AsyncLoading();
    try {
      await _repo.createTask(salesmanId: salesmanId, title: title, description: description, dueDate: dueDate);
      ref.invalidate(salesmanTasksProvider(salesmanId));
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

  Future<bool> updateTaskStatus(String taskId, String status) async {
    state = const AsyncLoading();
    try {
      await _repo.updateTaskStatus(taskId, status);
      ref.invalidate(myTasksProvider);
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

final salesmanMutationControllerProvider = AsyncNotifierProvider<SalesmanMutationController, void>(
  SalesmanMutationController.new,
);
