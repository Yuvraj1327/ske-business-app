import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../domain/settlement_models.dart';
import '../providers/settlement_providers.dart';

/// One row of a Settlement Sheet being built (or added later by the
/// Delivery Agent): search existing Customers by Code — the full code, or
/// just the last few digits (e.g. the last 6) — and pick one from the
/// matches, or — if nothing matches — create a new customer with that
/// code on the spot, then set the row's Invoice Amount and (optional)
/// Credit/Udhaar Amount.
Future<DraftSettlementRow?> showAddSettlementRowDialog(BuildContext context) {
  return showDialog<DraftSettlementRow>(
    context: context,
    builder: (_) => const _AddSettlementRowDialog(),
  );
}

class _AddSettlementRowDialogState extends ConsumerState<_AddSettlementRowDialog> {
  final _codeController = TextEditingController();
  final _newCustomerNameController = TextEditingController();
  final _newCustomerPhoneController = TextEditingController();
  final _invoiceAmountController = TextEditingController(text: '0');
  final _creditAmountController = TextEditingController(text: '0');
  final _amountsFormKey = GlobalKey<FormState>();

  Customer? _resolvedCustomer;
  bool _hasSearched = false;
  bool _showCreateNewCustomer = false;
  bool _isCreatingCustomer = false;

  @override
  void dispose() {
    _codeController.dispose();
    _newCustomerNameController.dispose();
    _newCustomerPhoneController.dispose();
    _invoiceAmountController.dispose();
    _creditAmountController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    if (code.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least 3 characters to search.')),
      );
      return;
    }
    setState(() {
      _resolvedCustomer = null;
      _hasSearched = true;
      _showCreateNewCustomer = false;
    });
    await ref.read(customerCodeSearchControllerProvider.notifier).search(code);
    if (!mounted) return;
    final state = ref.read(customerCodeSearchControllerProvider);
    state.when(
      data: (results) {
        // Nothing matched this code at all — offer "create a new
        // customer" right away instead of making the user find the link.
        if (results.isEmpty) setState(() => _showCreateNewCustomer = true);
      },
      loading: () {},
      error: (error, _) {
        final failure = error is Failure ? error : Failure.unknown(error.toString());
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error));
      },
    );
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _resolvedCustomer = customer;
      _showCreateNewCustomer = false;
    });
  }

  Future<void> _createCustomerAndUse() async {
    if (_newCustomerNameController.text.trim().isEmpty) return;
    setState(() => _isCreatingCustomer = true);
    try {
      final customer = await ref.read(customerRepositoryProvider).createCustomer(
            name: _newCustomerNameController.text.trim(),
            phone: _newCustomerPhoneController.text.trim().isEmpty ? null : _newCustomerPhoneController.text.trim(),
            externalCode: _codeController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _resolvedCustomer = customer;
        _showCreateNewCustomer = false;
      });
    } on Failure catch (f) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _isCreatingCustomer = false);
    }
  }

  String? _validateNonNegativeAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter an amount';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Amount cannot be negative';
    return null;
  }

  void _addRow() {
    if (_resolvedCustomer == null) return;
    if (!_amountsFormKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      DraftSettlementRow(
        customerId: _resolvedCustomer!.id,
        customerCode: _resolvedCustomer!.externalCode ?? _codeController.text.trim(),
        customerName: _resolvedCustomer!.name,
        invoiceAmount: double.parse(_invoiceAmountController.text.trim()),
        creditAmount: double.parse(_creditAmountController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(customerCodeSearchControllerProvider);
    final results = searchState.valueOrNull ?? const <Customer>[];
    final noResults = _hasSearched && !searchState.isLoading && results.isEmpty;

    return AlertDialog(
      title: const Text('Add Customer Row'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Customer Code',
                controller: _codeController,
                hintText: 'Full code, or just the last 6 digits e.g. 103533',
                enabled: _resolvedCustomer == null,
                suffixIcon: _resolvedCustomer == null
                    ? IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: searchState.isLoading ? null : _search,
                      )
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Search a different code',
                        onPressed: () => setState(() {
                          _resolvedCustomer = null;
                          _hasSearched = false;
                          _showCreateNewCustomer = false;
                          ref.read(customerCodeSearchControllerProvider.notifier).clear();
                        }),
                      ),
              ),
              if (searchState.isLoading) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              if (_resolvedCustomer == null && _hasSearched && !searchState.isLoading && results.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${results.length} match${results.length == 1 ? '' : 'es'} found — select one:',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return ListTile(
                          dense: true,
                          title: Text(c.name),
                          subtitle: Text('Code: ${c.externalCode ?? '-'}'),
                          onTap: () => _selectCustomer(c),
                        );
                      },
                    ),
                  ),
                ),
              ],
              // Both paths are offered up front — Admin/Delivery Agent
              // don't have to search and hit "no matches" first to
              // discover they can create a new customer here.
              if (_resolvedCustomer == null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showCreateNewCustomer = !_showCreateNewCustomer),
                    icon: Icon(_showCreateNewCustomer ? Icons.search : Icons.person_add_alt_1_outlined, size: 18),
                    label: Text(
                      _showCreateNewCustomer ? 'Search an existing customer instead' : 'Or create a new customer',
                    ),
                  ),
                ),
              ],
              if (_resolvedCustomer != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_resolvedCustomer!.name} · Code: ${_resolvedCustomer!.externalCode ?? '-'}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Form(
                  key: _amountsFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Invoice Amount',
                        controller: _invoiceAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validateNonNegativeAmount,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Estimated Credit / Udhaar (optional)',
                        controller: _creditAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        hintText: 'The Delivery Agent will set the final amount after delivery',
                        validator: _validateNonNegativeAmount,
                      ),
                    ],
                  ),
                ),
              ] else if (_showCreateNewCustomer) ...[
                const SizedBox(height: 14),
                if (noResults) ...[
                  Text(
                    'No customer found with this code — create one below.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                ],
                AppTextField(
                  label: 'New Customer Name',
                  controller: _newCustomerNameController,
                  enabled: !_isCreatingCustomer,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Phone (optional)',
                  controller: _newCustomerPhoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_isCreatingCustomer,
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Create Customer',
                  isLoading: _isCreatingCustomer,
                  onPressed: _createCustomerAndUse,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        if (_resolvedCustomer != null)
          AppButton(label: 'Add Row', expand: false, onPressed: _addRow),
      ],
    );
  }
}

class _AddSettlementRowDialog extends ConsumerStatefulWidget {
  const _AddSettlementRowDialog();

  @override
  ConsumerState<_AddSettlementRowDialog> createState() => _AddSettlementRowDialogState();
}
