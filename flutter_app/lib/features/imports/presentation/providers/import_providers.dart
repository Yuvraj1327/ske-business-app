import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../data/import_repository.dart';
import '../../domain/import_models.dart';

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return ImportRepository(ref.watch(apiClientProvider));
});

final importJobsListProvider = FutureProvider.autoDispose<Page<ImportJob>>((ref) {
  return ref.watch(importRepositoryProvider).listJobs();
});

final importJobRowsProvider = FutureProvider.autoDispose.family<Page<ImportJobRow>, String>((ref, jobId) {
  return ref.watch(importRepositoryProvider).getJobRows(jobId, status: 'failed');
});

class ImportMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<ImportJob?> uploadFile({required String entityType, required List<int> fileBytes, required String fileName}) async {
    state = const AsyncLoading();
    try {
      final job = await ref.read(importRepositoryProvider).uploadFile(entityType: entityType, fileBytes: fileBytes, fileName: fileName);
      ref.invalidate(importJobsListProvider);
      state = const AsyncData(null);
      return job;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }
}

final importMutationControllerProvider = AsyncNotifierProvider<ImportMutationController, void>(
  ImportMutationController.new,
);
