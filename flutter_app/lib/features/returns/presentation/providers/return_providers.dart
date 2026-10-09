import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/file_download/file_download.dart';
import '../../../../shared_models/page.dart';
import '../../data/return_repository.dart';
import '../../domain/return_models.dart';

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  return ReturnRepository(ref.watch(apiClientProvider));
});

class ReturnsFilter extends Equatable {
  final int page;

  const ReturnsFilter({this.page = 1});

  ReturnsFilter copyWith({int? page}) => ReturnsFilter(page: page ?? this.page);

  @override
  List<Object?> get props => [page];
}

final returnsFilterProvider = StateProvider.autoDispose<ReturnsFilter>((ref) => const ReturnsFilter());

final returnsListProvider = FutureProvider.autoDispose<Page<SalesReturn>>((ref) {
  final filter = ref.watch(returnsFilterProvider);
  return ref.watch(returnRepositoryProvider).listReturns(page: filter.page);
});

/// Returns for a single sale — used to show what's already been returned
/// when computing "returnable" quantity in the Create Return screen.
final saleReturnsProvider = FutureProvider.autoDispose.family<Page<SalesReturn>, String>((ref, saleId) {
  return ref.watch(returnRepositoryProvider).listReturns(saleId: saleId, pageSize: 50);
});

/// Total quantity already returned per sale line (keyed by sale item id), for
/// display only — the backend stays the source of truth for the real limit.
Map<String, double> alreadyReturnedBySaleItem(Iterable<SalesReturn> returns) {
  final result = <String, double>{};
  for (final ret in returns) {
    for (final item in ret.items) {
      result[item.saleItemId] = (result[item.saleItemId] ?? 0) + item.quantity;
    }
  }
  return result;
}

class ReturnMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<SalesReturn?> createReturn({
    required String saleId,
    required List<({String saleItemId, double quantity})> items,
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(returnRepositoryProvider).createReturn(saleId: saleId, items: items, reason: reason);
      ref.invalidate(returnsListProvider);
      ref.invalidate(saleReturnsProvider(saleId));
      state = const AsyncData(null);
      return result;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }
}

final returnMutationControllerProvider = AsyncNotifierProvider<ReturnMutationController, void>(
  ReturnMutationController.new,
);

enum ReturnExportResult { saved, cancelled, failed }

const _xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Downloads every sales return (all pages) as sales_returns_YYYY-MM-DD.xlsx.
/// `isLoading` drives the button spinner; a failure is left in the state.
class ReturnExportController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<ReturnExportResult> exportXlsx() async {
    if (state.isLoading) return ReturnExportResult.cancelled;
    state = const AsyncLoading();
    try {
      final bytes = await ref.read(returnRepositoryProvider).exportReturnsXlsx();
      final fileName = 'sales_returns_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      final saved = await saveBytesAsFile(bytes: bytes, fileName: fileName, mimeType: _xlsxMimeType);
      state = const AsyncData(null);
      return saved ? ReturnExportResult.saved : ReturnExportResult.cancelled;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return ReturnExportResult.failed;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return ReturnExportResult.failed;
    }
  }
}

final returnExportControllerProvider = AsyncNotifierProvider<ReturnExportController, void>(
  ReturnExportController.new,
);
