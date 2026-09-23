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

/// Admin-only: build a new Settlement Sheet. Only the Basic Details section
/// is required (Date, Delivery Agent, one or more PSR/Salesmen, Pick Sheet
/// No./Value) — the Settlement Summary reconciliation fields and customer
/// rows are both optional here and can be filled in/added later (rows by
/// the Delivery Agent from the detail screen's "+ Add Customer").
class CreateSettlementScreen extends ConsumerStatefulWidget {
  const CreateSettlementScreen({super.key});

  @override
  ConsumerState<CreateSettlementScreen> createState() => _CreateSettlementScreenState();
}

class _CreateSettlementScreenState extends ConsumerState<CreateSettlementScreen> {
  DateTime _sheetDate = DateTime.now();
  String? _deliveryAgentId;
  final Set<String> _selectedSalesmanIds = {};
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
    if (_deliveryAgentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Delivery Agent.')),
      );
      return;
    }
    if (_selectedSalesmanIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one PSR / Salesman.')),
      );
      return;
    }

    final sheet = await ref.read(settlementMutationControllerProvider.notifier).createSheet(
          sheetDate: _sheetDate,
          deliveryAgentId: _deliveryAgentId!,
          salesmanIds: _selectedSalesmanIds.toList(),
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
          const Text('New Settlement Sheet', style: AppTextStyles.heading1),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionHeader(title: 'Basic Details'),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sheet Date'),
                        subtitle: Text(Formatters.date(_sheetDate)),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 10),
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
                      Text('PSR / Salesman', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Select one or more — each will only manage their own customers\' credit/udhaar.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 6),
                      salesmenAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Could not load salesmen: $e'),
                        data: (salesmen) => Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: salesmen
                                .map(
                                  (s) => CheckboxListTile(
                                    dense: true,
                                    title: Text(s.fullName),
                                    value: _selectedSalesmanIds.contains(s.id),
                                    onChanged: (checked) => setState(() {
                                      if (checked ?? false) {
                                        _selectedSalesmanIds.add(s.id);
                                      } else {
                                        _selectedSalesmanIds.remove(s.id);
                                      }
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(label: 'Pick Sheet No.', controller: _pickSheetNoController),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Pick Sheet Value',
                        controller: _pickSheetValueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'Settlement Summary',
                    subtitle: 'Optional — can be filled in now or later, anytime before the sheet is completed.',
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
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
                      const SizedBox(height: 14),
                      AppTextField(label: 'Notes (optional)', controller: _notesController, maxLines: 2),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Customer-wise Details',
                    subtitle: 'Optional — you or the Delivery Agent can add customers now or later.',
                    trailing: TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Row'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('No rows yet. Add a customer by their Code.', style: AppTextStyles.bodySecondary),
                    )
                  else
                    ..._rows.asMap().entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
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
            label: 'Create Settlement Sheet',
            isLoading: mutationState.isLoading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// A section title with an optional one-line subtitle and trailing action —
/// used to keep Basic Details / Settlement Summary / Customer-wise Details
/// visually distinct instead of one long undifferentiated form.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppTextStyles.heading3),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppTextStyles.bodySecondary),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}
