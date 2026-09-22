import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared_models/page.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../roles/domain/role_models.dart';
import '../../../roles/presentation/providers/role_providers.dart';
import '../../../users/domain/managed_user.dart';
import '../../../users/presentation/providers/user_providers.dart';
import '../../data/settlement_repository.dart';
import '../../domain/settlement_models.dart';

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(ref.watch(apiClientProvider));
});

// The active Delivery Agent dropdown reuses the SAME provider the
// Picklists feature already defined — `deliveryAgentsProvider` in
// features/picklists/presentation/providers/picklist_providers.dart
// (resolve the 'delivery_agent' role, then list active users in it).
// Screens here import it directly from that file. No second copy of that
// lookup lives here.

/// The active Salesman dropdown — same mechanism as [deliveryAgentsProvider]
/// (GET /roles to resolve the 'salesman' role id, then GET /users filtered
/// by it, active only), just for the other role this feature needs.
final activeSalesmenProvider = FutureProvider.autoDispose<List<ManagedUser>>((ref) async {
  final roles = await ref.watch(rolesListProvider.future);
  AppRole? salesmanRole;
  for (final r in roles) {
    if (r.name == 'salesman') {
      salesmanRole = r;
      break;
    }
  }
  if (salesmanRole == null) return [];

  final page = await ref.watch(userRepositoryProvider).listUsers(
        pageSize: 100,
        roleId: salesmanRole.id,
        isActive: true,
      );
  return page.items;
});

/// Admin sees every sheet; a Delivery Agent or Salesman sees only sheets
/// they're assigned to — enforced server-side (see
/// SettlementService.list_sheets), so this is the same query for everyone.
final settlementsListProvider =
    FutureProvider.autoDispose.family<Page<SettlementSheet>, String?>((ref, status) {
  return ref.watch(settlementRepositoryProvider).listSheets(pageSize: 50, status: status);
});

final settlementDetailProvider = FutureProvider.autoDispose.family<SettlementSheetDetail, String>((ref, id) {
  return ref.watch(settlementRepositoryProvider).getSheet(id);
});

/// Customer Code search + autofill, used while building/updating a
/// settlement sheet. Matches on just the END of the code (e.g. the last 6
/// digits), which also covers a full-code search since that's just the
/// extreme case of a suffix match. Returns an empty list (no error) when
/// nothing has been searched yet, or when a search genuinely finds
/// nothing — the "add row" dialog treats an empty result (after a search
/// was actually run) as the trigger to offer "create a new customer with
/// this code" instead of showing a generic error banner.
class CustomerCodeSearchController extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async => [];

  Future<void> search(String code) async {
    state = const AsyncLoading();
    try {
      final results = await ref.read(customerRepositoryProvider).searchByCode(code);
      state = AsyncData(results);
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
    }
  }

  void clear() => state = const AsyncData([]);
}

final customerCodeSearchControllerProvider =
    AsyncNotifierProvider<CustomerCodeSearchController, List<Customer>>(CustomerCodeSearchController.new);

/// Handles create-sheet, status transitions and both per-row update
/// mutations, refreshing whichever list/detail provider is affected.
class SettlementMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  SettlementRepository get _repo => ref.read(settlementRepositoryProvider);

  Future<SettlementSheetDetail?> createSheet({
    required DateTime sheetDate,
    required String deliveryAgentId,
    required List<String> salesmanIds,
    String? notes,
    String? pickSheetNo,
    double pickSheetValue = 0,
    double returnsAmount = 0,
    double damageReturnAmount = 0,
    double discountAmount = 0,
    double cashAmount = 0,
    double onlineAmount = 0,
    double chequeAmount = 0,
    double creditBillsAmount = 0,
    double oldShortAmount = 0,
    List<DraftSettlementRow> items = const [],
  }) async {
    state = const AsyncLoading();
    try {
      final sheet = await _repo.createSheet(
        sheetDate: sheetDate,
        deliveryAgentId: deliveryAgentId,
        salesmanIds: salesmanIds,
        notes: notes,
        pickSheetNo: pickSheetNo,
        pickSheetValue: pickSheetValue,
        returnsAmount: returnsAmount,
        damageReturnAmount: damageReturnAmount,
        discountAmount: discountAmount,
        cashAmount: cashAmount,
        onlineAmount: onlineAmount,
        chequeAmount: chequeAmount,
        creditBillsAmount: creditBillsAmount,
        oldShortAmount: oldShortAmount,
        items: items,
      );
      ref.invalidate(settlementsListProvider);
      state = const AsyncData(null);
      return sheet;
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
      return null;
    } catch (e) {
      state = AsyncError(Failure.unknown(e.toString()), StackTrace.current);
      return null;
    }
  }

  Future<bool> updateStatus(String sheetId, String status) =>
      _run(() => _repo.updateStatus(sheetId, status), sheetId: sheetId);

  Future<bool> updateSheetHeader({
    required String sheetId,
    DateTime? sheetDate,
    String? deliveryAgentId,
    List<String>? salesmanIds,
    String? notes,
    String? pickSheetNo,
    double? pickSheetValue,
    double? returnsAmount,
    double? damageReturnAmount,
    double? discountAmount,
    double? cashAmount,
    double? onlineAmount,
    double? chequeAmount,
    double? creditBillsAmount,
    double? oldShortAmount,
  }) =>
      _run(
        () => _repo.updateSheet(
          sheetId,
          sheetDate: sheetDate,
          deliveryAgentId: deliveryAgentId,
          salesmanIds: salesmanIds,
          notes: notes,
          pickSheetNo: pickSheetNo,
          pickSheetValue: pickSheetValue,
          returnsAmount: returnsAmount,
          damageReturnAmount: damageReturnAmount,
          discountAmount: discountAmount,
          cashAmount: cashAmount,
          onlineAmount: onlineAmount,
          chequeAmount: chequeAmount,
          creditBillsAmount: creditBillsAmount,
          oldShortAmount: oldShortAmount,
        ),
        sheetId: sheetId,
      );

  /// Add one customer row to an already-existing sheet.
  Future<bool> addItem({
    required String sheetId,
    required String customerId,
    required double invoiceAmount,
    required double creditAmount,
  }) =>
      _run(
        () => _repo.addItem(
          sheetId,
          customerId: customerId,
          invoiceAmount: invoiceAmount,
          creditAmount: creditAmount,
        ),
        sheetId: sheetId,
      );

  Future<bool> updateItemDelivery({
    required String sheetId,
    required String itemId,
    required String deliveryStatus,
    required double cashAmount,
    required double onlineAmount,
    required double chequeAmount,
    required double creditAmount,
    String? agentNotes,
  }) =>
      _run(
        () => _repo.updateItemDelivery(
          itemId: itemId,
          deliveryStatus: deliveryStatus,
          cashAmount: cashAmount,
          onlineAmount: onlineAmount,
          chequeAmount: chequeAmount,
          creditAmount: creditAmount,
          agentNotes: agentNotes,
        ),
        sheetId: sheetId,
      );

  Future<bool> updateItemCredit({
    required String sheetId,
    required String itemId,
    required double creditCollected,
    String? salesmanNotes,
  }) =>
      _run(
        () => _repo.updateItemCredit(itemId: itemId, creditCollected: creditCollected, salesmanNotes: salesmanNotes),
        sheetId: sheetId,
      );

  Future<bool> _run(Future<Object?> Function() action, {required String sheetId}) async {
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(settlementDetailProvider(sheetId));
      ref.invalidate(settlementsListProvider);
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

final settlementMutationControllerProvider =
    AsyncNotifierProvider<SettlementMutationController, void>(SettlementMutationController.new);
