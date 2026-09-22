import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../picklists/presentation/providers/picklist_providers.dart' show deliveryAgentsProvider;
import '../../domain/settlement_models.dart';
import '../providers/settlement_providers.dart';
import '../widgets/add_settlement_row_dialog.dart';

/// Admin-only: build a new Settlement Sheet — pick the date, the Delivery
/// Agent + Salesman whose route this is, add one row per customer (via
/// Customer Code search/autofill or on-the-spot customer creation), then
/// save it as a Draft. Moving it to "In Progress" happens from the detail
/// screen once it's ready to be worked.
class CreateSettlementScreen extends ConsumerStatefulWidget {
  const CreateSettlementScreen({super.key});

  @override
  ConsumerState<CreateSettlementScreen> createState() => _CreateSettlementScreenState();
}

class _CreateSettlementScreenState extends ConsumerState<CreateSettlementScreen> {
  DateTime _sheetDate = DateTime.now();
  String? _deliveryAgentId;
  String? _salesmanId;
  final _notesController = TextEditingController();
  final _pickSheetNoController = TextEditingController();
  final _pickSheetValueController = TextEditingController(text: '0');
  final _returnsAmountController = TextEditingController(text: '0');
  final _damageReturnAmountController = TextEditingController(text: '0');
  final _discountAmountController = TextEditingController(text: '0');
  final _cashController = TextEditingController(text: '0');
  final _onlineController = TextEditingController(text: '0');
  final _chequeController = TextEditingController(text: '0');
  final _creditBillsAmountController = TextEditingController(text: '0');
  final _oldShortAmountController = TextEditingController(text: '0');
  final List<DraftSettlementRow> _rows = [];

  @override
  void dispose() {
    _notesController.dispose();
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
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sheetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _sheetDate = picked);
  }

  Future<void> _addRow() async {
    final row = await showAddSettlementRowDialog(context);
    if (row != null) setState(() => _rows.add(row));
  }

  Future<void> _save() async {
    if (_deliveryAgentId == null || _salesmanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both a Delivery Agent and a Salesman.')),
      );
      return;
    }
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one customer row.')),
      );
      return;
    }

    final sheet = await ref.read(settlementMutationControllerProvider.notifier).createSheet(
          sheetDate: _sheetDate,
          deliveryAgentId: _deliveryAgentId!,
          salesmanId: _salesmanId!,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          pickSheetNo: _pickSheetNoController.text.trim().isEmpty ? null : _pickSheetNoController.text.trim(),
          pickSheetValue: _num(_pickSheetValueController),
          returnsAmount: _num(_returnsAmountController),
          damageReturnAmount: _num(_damageReturnAmountController),
          discountAmount: _num(_discountAmountController),
          cashAmount: _num(_cashController),
          onlineAmount: _num(_onlineController),
          chequeAmount: _num(_chequeController),
          creditBillsAmount: _num(_creditBillsAmountController),
          oldShortAmount: _num(_oldShortAmountController),
          items: _rows,
        );

    if (!mounted) return;
    if (sheet != null) {
      context.go('/settlements/${sheet.id}');
    } else {
      final state = ref.read(settlementMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(deliveryAgentsProvider);
    final salesmenAsync = ref.watch(activeSalesmenProvider);
    final mutationState = ref.watch(settlementMutationControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New Settlement Sheet', style: AppTextStyles.heading1),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sheet Date'),
                    subtitle: Text(Formatters.date(_sheetDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 8),
                  agentsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Could not load delivery agents: $e'),
                    data: (agents) => DropdownButtonFormField<String>(
                      value: _deliveryAgentId,
                      decoration: const InputDecoration(labelText: 'Delivery Agent'),
                      items: agents
                          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.fullName)))
                          .toList(),
                      onChanged: (v) => setState(() => _deliveryAgentId = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  salesmenAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Could not load salesmen: $e'),
                    data: (salesmen) => DropdownButtonFormField<String>(
                      value: _salesmanId,
                      decoration: const InputDecoration(labelText: 'PSR / Salesman'),
                      items: salesmen
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.fullName)))
                          .toList(),
                      onChanged: (v) => setState(() => _salesmanId = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Notes (optional)', controller: _notesController, maxLines: 2),
                  const SizedBox(height: 24),
                  Text('General Settlement Details', style: AppTextStyles.heading3),
                  const SizedBox(height: 4),
                  Text(
                    'Reconciliation totals for this route — Admin can edit these anytime before the sheet is completed.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(label: 'Pick Sheet No.', controller: _pickSheetNoController),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Pick Sheet Value',
                            controller: _pickSheetValueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Returns Goods',
                            controller: _returnsAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Damage Return',
                            controller: _damageReturnAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Discount',
                            controller: _discountAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Cash',
                            controller: _cashController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Online / Bank / UPI',
                            controller: _onlineController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Cheque',
                            controller: _chequeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Credit Bills',
                            controller: _creditBillsAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Old Short',
                            controller: _oldShortAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Customers (${_rows.length})', style: AppTextStyles.heading3),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Row'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_rows.isEmpty)
                    Text('No rows yet. Add a customer by their Code.', style: AppTextStyles.bodySecondary)
                  else
                    ..._rows.asMap().entries.map(
                          (entry) => Card(
                            child: ListTile(
                              title: Text(entry.value.customerName),
                              subtitle: Text(
                                'Code: ${entry.value.customerCode ?? '-'} · Invoice: ${Formatters.currency(entry.value.invoiceAmount)}'
                                '${entry.value.creditAmount > 0 ? ' · Credit: ${Formatters.currency(entry.value.creditAmount)}' : ''}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() => _rows.removeAt(entry.key)),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Save Settlement Sheet',
            isLoading: mutationState.isLoading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
