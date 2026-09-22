import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/settlement_models.dart';
import '../providers/settlement_providers.dart';
import '../widgets/add_settlement_row_dialog.dart';

/// Full detail of one Settlement Sheet, laid out as clear sections —
/// Basic Details -> Settlement Summary -> Customer-wise Details -> Final
/// Review — so each role can immediately tell where they act (checked
/// client-side only for UX; the real enforcement is server-side in
/// SettlementService):
///   - Admin: full access everywhere, plus Final Review's Start/Complete
///     actions.
///   - The assigned Delivery Agent: adds/updates customer rows' delivery
///     half any time before the sheet is 'completed'.
///   - Each assigned Salesman: updates the Credit/Udhaar half only for
///     rows whose customer is actually assigned to them, while
///     'in_progress'.
class SettlementDetailScreen extends ConsumerStatefulWidget {
  const SettlementDetailScreen({super.key, required this.sheetId});

  final String sheetId;

  @override
  ConsumerState<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends ConsumerState<SettlementDetailScreen> {
  // Salesman-only working view: by default only show rows with a
  // credit/udhaar amount assigned to THEM, since that's the only half of
  // the sheet a Salesman acts on. Admin and the Delivery Agent always see
  // every row.
  bool _creditOnlyFilter = true;

  Future<void> _addCustomer(String sheetId) async {
    final row = await showAddSettlementRowDialog(context);
    if (row == null) return;
    final success = await ref.read(settlementMutationControllerProvider.notifier).addItem(
          sheetId: sheetId,
          customerId: row.customerId,
          invoiceAmount: row.invoiceAmount,
          creditAmount: row.creditAmount,
        );
    if (!mounted) return;
    if (!success) {
      final state = ref.read(settlementMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(settlementDetailProvider(widget.sheetId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(settlementDetailProvider(widget.sheetId)),
        ),
        data: (sheet) {
          final isAdmin = user?.isAdmin ?? false;
          final isAgent = user != null && user.id == sheet.deliveryAgentId;
          final isSalesmanOnSheet = user != null && sheet.salesmen.any((s) => s.id == user.id);
          final isSalesmanOnly = isSalesmanOnSheet && !isAdmin && !isAgent;
          final canAddCustomer = (isAdmin || isAgent) && sheet.status != 'completed';

          bool relevantToMe(SettlementSheetItem i) =>
              i.creditAmount > 0 && (i.assignedSalesmanId == null || i.assignedSalesmanId == user?.id);

          final visibleItems =
              (isSalesmanOnly && _creditOnlyFilter) ? sheet.items.where(relevantToMe).toList() : sheet.items;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BasicDetailsCard(sheet: sheet),
                const SizedBox(height: 16),
                _SettlementSummaryCard(sheet: sheet, isAdmin: isAdmin),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Customer-wise Details', style: AppTextStyles.heading3),
                    const Spacer(),
                    if (canAddCustomer)
                      FilledButton.tonalIcon(
                        onPressed: () => _addCustomer(sheet.id),
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                        label: const Text('Add Customer'),
                      ),
                  ],
                ),
                if (isSalesmanOnly) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _creditOnlyFilter = !_creditOnlyFilter),
                      child: Text(_creditOnlyFilter ? 'Show all customers' : 'Credit customers only'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (visibleItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      isSalesmanOnly
                          ? 'No credit/udhaar customers assigned to you on this sheet.'
                          : 'No customers on this sheet yet.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  )
                else
                  ...visibleItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ItemCard(
                        sheet: sheet,
                        item: item,
                        canEditDelivery: (isAdmin || isAgent) && sheet.status == 'in_progress',
                        canEditCredit: (isAdmin ||
                                (isSalesmanOnSheet &&
                                    (item.assignedSalesmanId == null || item.assignedSalesmanId == user.id))) &&
                            sheet.status == 'in_progress',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _FinalReviewSection(sheet: sheet, isAdmin: isAdmin),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return AppColors.success;
    case 'in_progress':
      return AppColors.accent;
    default:
      return AppColors.textSecondary;
  }
}

class _BasicDetailsCard extends StatelessWidget {
  const _BasicDetailsCard({required this.sheet});

  final SettlementSheetDetail sheet;

  @override
  Widget build(BuildContext context) {
    final summary = sheet.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Details', style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(sheet.sheetNo, style: AppTextStyles.heading1)),
                StatusBadge(label: Formatters.roleLabel(sheet.status), color: _statusColor(sheet.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Formatters.date(sheet.sheetDate)} · Agent: ${sheet.deliveryAgentName}',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 2),
            Text(
              'PSR / Salesman: ${sheet.salesmen.map((s) => s.name).join(', ')}',
              style: AppTextStyles.bodySecondary,
            ),
            if (sheet.notes != null && sheet.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(sheet.notes!, style: AppTextStyles.body),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _StatLabel(label: 'Total Invoice', value: Formatters.currency(summary.totalInvoiceAmount)),
                _StatLabel(label: 'Collected', value: Formatters.currency(summary.totalCollected)),
                _StatLabel(label: 'Credit Outstanding', value: Formatters.currency(summary.totalCreditOutstanding)),
                _StatLabel(label: 'Pending Rows', value: '${summary.pending}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementSummaryCard extends ConsumerStatefulWidget {
  const _SettlementSummaryCard({required this.sheet, required this.isAdmin});

  final SettlementSheetDetail sheet;
  final bool isAdmin;

  @override
  ConsumerState<_SettlementSummaryCard> createState() => _SettlementSummaryCardState();
}

class _SettlementSummaryCardState extends ConsumerState<_SettlementSummaryCard> {
  bool _editing = false;

  late final TextEditingController _pickSheetNoController =
      TextEditingController(text: widget.sheet.pickSheetNo ?? '');
  late final TextEditingController _pickSheetValueController =
      TextEditingController(text: widget.sheet.pickSheetValue.toStringAsFixed(2));
  late final TextEditingController _returnsAmountController =
      TextEditingController(text: widget.sheet.returnsAmount.toStringAsFixed(2));
  late final TextEditingController _damageReturnAmountController =
      TextEditingController(text: widget.sheet.damageReturnAmount.toStringAsFixed(2));
  late final TextEditingController _discountAmountController =
      TextEditingController(text: widget.sheet.discountAmount.toStringAsFixed(2));
  late final TextEditingController _cashController =
      TextEditingController(text: widget.sheet.cashAmount.toStringAsFixed(2));
  late final TextEditingController _onlineController =
      TextEditingController(text: widget.sheet.onlineAmount.toStringAsFixed(2));
  late final TextEditingController _chequeController =
      TextEditingController(text: widget.sheet.chequeAmount.toStringAsFixed(2));
  late final TextEditingController _creditBillsAmountController =
      TextEditingController(text: widget.sheet.creditBillsAmount.toStringAsFixed(2));
  late final TextEditingController _oldShortAmountController =
      TextEditingController(text: widget.sheet.oldShortAmount.toStringAsFixed(2));
  late final TextEditingController _notesController = TextEditingController(text: widget.sheet.notes ?? '');

  @override
  void dispose() {
    _pickSheetNoController.dispose();
    _pickSheetValueController.dispose();
    _returnsAmountController.dispose();
    _damageReturnAmountController.dispose();
    _discountAmountController.dispose();
    _cashController.dispose();
    _onlineController.dispose();
    _chequeController.dispose();
    _creditBillsAmountController.dispose();
    _oldShortAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateSheetHeader(
          sheetId: widget.sheet.id,
          notes: _notesController.text.trim(),
          pickSheetNo: _pickSheetNoController.text.trim(),
          pickSheetValue: _num(_pickSheetValueController),
          returnsAmount: _num(_returnsAmountController),
          damageReturnAmount: _num(_damageReturnAmountController),
          discountAmount: _num(_discountAmountController),
          cashAmount: _num(_cashController),
          onlineAmount: _num(_onlineController),
          chequeAmount: _num(_chequeController),
          creditBillsAmount: _num(_creditBillsAmountController),
          oldShortAmount: _num(_oldShortAmountController),
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editing = false);
    } else {
      _showError();
    }
  }

  void _showError() {
    final state = ref.read(settlementMutationControllerProvider);
    final failure = state.hasError ? state.error as Failure : Failure.unknown();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    final mutationState = ref.watch(settlementMutationControllerProvider);
    final canEdit = widget.isAdmin && sheet.status != 'completed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Settlement Summary', style: AppTextStyles.heading3),
                const Spacer(),
                if (canEdit && !_editing)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit settlement details',
                    onPressed: () => setState(() => _editing = true),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_editing)
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _StatLabel(
                    label: 'Pick Sheet No.',
                    value: sheet.pickSheetNo?.isNotEmpty == true ? sheet.pickSheetNo! : '-',
                  ),
                  _StatLabel(label: 'Pick Sheet Value', value: Formatters.currency(sheet.pickSheetValue)),
                  _StatLabel(label: 'Returns Goods', value: Formatters.currency(sheet.returnsAmount)),
                  _StatLabel(label: 'Damage Return', value: Formatters.currency(sheet.damageReturnAmount)),
                  _StatLabel(label: 'Discount', value: Formatters.currency(sheet.discountAmount)),
                  _StatLabel(label: 'Cash', value: Formatters.currency(sheet.cashAmount)),
                  _StatLabel(label: 'Online / Bank / UPI', value: Formatters.currency(sheet.onlineAmount)),
                  _StatLabel(label: 'Cheque', value: Formatters.currency(sheet.chequeAmount)),
                  _StatLabel(label: 'Credit Bills', value: Formatters.currency(sheet.creditBillsAmount)),
                  _StatLabel(label: 'Old Short', value: Formatters.currency(sheet.oldShortAmount)),
                ],
              )
            else ...[
              AppTextField(label: 'Pick Sheet No.', controller: _pickSheetNoController),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Pick Sheet Value',
                controller: _pickSheetValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Returns Goods',
                controller: _returnsAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Damage Return',
                controller: _damageReturnAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Discount',
                controller: _discountAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Cash',
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Online / Bank / UPI',
                controller: _onlineController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Cheque',
                controller: _chequeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Credit Bills',
                controller: _creditBillsAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Old Short',
                controller: _oldShortAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(label: 'Notes (optional)', controller: _notesController, maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _save),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Admin's closing action on the sheet — Start (Draft -> In Progress) and
/// Complete Sheet, kept as its own clearly-labeled section at the very
/// bottom so it reads as the final step after everything else has been
/// filled in, not something buried in the header.
class _FinalReviewSection extends ConsumerWidget {
  const _FinalReviewSection({required this.sheet, required this.isAdmin});

  final SettlementSheetDetail sheet;
  final bool isAdmin;

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateStatus(sheet.id, newStatus);
    if (!context.mounted) return;
    if (!success) {
      final state = ref.read(settlementMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAdmin || sheet.status == 'completed') {
      if (sheet.status == 'completed') {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Final Review complete — this settlement sheet is Completed.', style: AppTextStyles.body),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final mutationState = ref.watch(settlementMutationControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Final Review', style: AppTextStyles.heading3),
            const SizedBox(height: 6),
            Text(
              sheet.status == 'draft'
                  ? 'Move this sheet to In Progress once the Delivery Agent and Salesmen are ready to start updating it.'
                  : 'Review all customer rows above, then mark this sheet Completed once everything is confirmed.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (sheet.status == 'draft')
                  AppButton(
                    label: 'Start (Move to In Progress)',
                    expand: false,
                    isLoading: mutationState.isLoading,
                    onPressed: () => _changeStatus(context, ref, 'in_progress'),
                  ),
                if (sheet.status == 'in_progress')
                  AppButton(
                    label: 'Complete Sheet',
                    expand: false,
                    isLoading: mutationState.isLoading,
                    onPressed: () => _changeStatus(context, ref, 'completed'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.amount),
      ],
    );
  }
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({
    required this.sheet,
    required this.item,
    required this.canEditDelivery,
    required this.canEditCredit,
  });

  final SettlementSheetDetail sheet;
  final SettlementSheetItem item;
  final bool canEditDelivery;
  final bool canEditCredit;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  bool _editingDelivery = false;
  bool _editingCredit = false;

  late String _deliveryStatus = widget.item.deliveryStatus == 'pending' ? 'delivered' : widget.item.deliveryStatus;
  late final TextEditingController _cashController =
      TextEditingController(text: widget.item.cashAmount.toStringAsFixed(2));
  late final TextEditingController _onlineController =
      TextEditingController(text: widget.item.onlineAmount.toStringAsFixed(2));
  late final TextEditingController _chequeController =
      TextEditingController(text: widget.item.chequeAmount.toStringAsFixed(2));
  late final TextEditingController _creditAmountController =
      TextEditingController(text: widget.item.creditAmount.toStringAsFixed(2));
  late final TextEditingController _agentNotesController = TextEditingController(text: widget.item.agentNotes ?? '');

  late final TextEditingController _creditCollectedController =
      TextEditingController(text: widget.item.creditCollected.toStringAsFixed(2));
  late final TextEditingController _salesmanNotesController =
      TextEditingController(text: widget.item.salesmanNotes ?? '');

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    _cashController.dispose();
    _onlineController.dispose();
    _chequeController.dispose();
    _creditAmountController.dispose();
    _agentNotesController.dispose();
    _creditCollectedController.dispose();
    _salesmanNotesController.dispose();
    super.dispose();
  }

  Color _deliveryColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.success;
      case 'not_delivered':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _saveDelivery() async {
    final notDelivered = _deliveryStatus == 'not_delivered';
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateItemDelivery(
          sheetId: widget.sheet.id,
          itemId: widget.item.id,
          deliveryStatus: _deliveryStatus,
          cashAmount: notDelivered ? 0 : _num(_cashController),
          onlineAmount: notDelivered ? 0 : _num(_onlineController),
          chequeAmount: notDelivered ? 0 : _num(_chequeController),
          creditAmount: notDelivered ? 0 : _num(_creditAmountController),
          agentNotes: _agentNotesController.text.trim().isEmpty ? null : _agentNotesController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingDelivery = false);
    } else {
      _showError();
    }
  }

  Future<void> _saveCredit() async {
    final collected = double.tryParse(_creditCollectedController.text.trim()) ?? 0;
    final success = await ref.read(settlementMutationControllerProvider.notifier).updateItemCredit(
          sheetId: widget.sheet.id,
          itemId: widget.item.id,
          creditCollected: collected,
          salesmanNotes: _salesmanNotesController.text.trim().isEmpty ? null : _salesmanNotesController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      setState(() => _editingCredit = false);
    } else {
      _showError();
    }
  }

  void _showError() {
    final state = ref.read(settlementMutationControllerProvider);
    final failure = state.hasError ? state.error as Failure : Failure.unknown();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final mutationState = ref.watch(settlementMutationControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.customerName, style: AppTextStyles.heading3, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(Formatters.currency(item.invoiceAmount), style: AppTextStyles.amount),
              ],
            ),
            if (item.customerCode != null) Text('Code: ${item.customerCode}', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusBadge(label: Formatters.roleLabel(item.deliveryStatus), color: _deliveryColor(item.deliveryStatus)),
                if (item.cashAmount > 0)
                  StatusBadge(label: 'Cash ${Formatters.currency(item.cashAmount)}', color: AppColors.success),
                if (item.onlineAmount > 0)
                  StatusBadge(label: 'Online ${Formatters.currency(item.onlineAmount)}', color: AppColors.success),
                if (item.chequeAmount > 0)
                  StatusBadge(label: 'Cheque ${Formatters.currency(item.chequeAmount)}', color: AppColors.success),
                if (item.creditAmount > 0)
                  StatusBadge(
                    label: 'Credit ${Formatters.currency(item.creditCollected)}/${Formatters.currency(item.creditAmount)}',
                    color: item.creditOutstanding > 0 ? AppColors.warning : AppColors.success,
                  ),
              ],
            ),
            if (widget.canEditDelivery || widget.canEditCredit) const SizedBox(height: 10),
            if (widget.canEditDelivery && !_editingDelivery)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _editingDelivery = true),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Update Delivery'),
                ),
              ),
            if (_editingDelivery) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deliveryStatus,
                      decoration: const InputDecoration(labelText: 'Delivery Status'),
                      items: const [
                        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(value: 'not_delivered', child: Text('Not Delivered')),
                      ],
                      onChanged: (v) => setState(() => _deliveryStatus = v ?? _deliveryStatus),
                    ),
                  ),
                ],
              ),
              if (_deliveryStatus != 'not_delivered') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cash Amount'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _onlineController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Online / UPI Amount'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _chequeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cheque Amount'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _creditAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Credit / Udhaar Amount'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _agentNotesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingDelivery = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveDelivery),
                ],
              ),
            ],
            if (widget.canEditCredit && !_editingCredit)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _editingCredit = true),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Update Credit / Udhaar'),
                ),
              ),
            if (_editingCredit) ...[
              const Divider(),
              Text('Credit Amount: ${Formatters.currency(item.creditAmount)}', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 10),
              TextField(
                controller: _creditCollectedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Credit Collected (total so far)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _salesmanNotesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _editingCredit = false), child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(label: 'Save', expand: false, isLoading: mutationState.isLoading, onPressed: _saveCredit),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
