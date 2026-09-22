import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../domain/settlement_models.dart';
import '../providers/settlement_providers.dart';

/// One row of a Settlement Sheet being built: search an existing Customer
/// by their Code and autofill, or — if the code isn't found — let Admin
/// create a new customer with that code on the spot, then set the row's
/// Invoice Amount and (optional) Credit/Udhaar Amount.
Future<DraftSettlementRow?> showAddSettlementRowDialog(BuildContext context) {
  return showDialog<DraftSettlementRow>(
    context: context,
    builder: (_) => const _AddSettlementRowDialog(),
  );
}

class _AddSettlementRowDialog extends ConsumerStatefulWidget {
  const _AddSettlementRowDialog();

  @override
  ConsumerState<_AddSettlementRowDialog> createState() => _AddSettlementRowDialogState();
}

class _AddSettlementRowDialogState extends ConsumerState<_AddSettlementRowDialog> {
  final _codeController = TextEditingController();
  final _newCustomerNameController = TextEditingController();
  final _newCustomerPhoneController = TextEditingController();
  final _invoiceAmountController = TextEditingController(text: '0');
  final _creditAmountController = TextEditingController(text: '0');
  final _amountsFormKey = GlobalKey<FormState>();

  Customer? _resolvedCustomer;
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
    setState(() {
      _resolvedCustomer = null;
      _showCreateNewCustomer = false;
    });
    await ref.read(customerCodeLookupControllerProvider.notifier).lookup(code);
    final result = ref.read(customerCodeLookupControllerProvider);
    result.whenOrNull(
      data: (customer) => setState(() => _resolvedCustomer = customer),
      error: (error, _) {
        if (error is Failure && error.code == 'NOT_FOUND') {
          setState(() => _showCreateNewCustomer = true);
        }
      },
    );
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
    final lookupState = ref.watch(customerCodeLookupControllerProvider);
    final notFound = lookupState.hasError &&
        lookupState.error is Failure &&
        (lookupState.error as Failure).code == 'NOT_FOUND';

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
                hintText: 'e.g. IEWG26133417',
                enabled: _resolvedCustomer == null,
                suffixIcon: _resolvedCustomer == null
                    ? IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: lookupState.isLoading ? null : _search,
                      )
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Search a different code',
                        onPressed: () => setState(() {
                          _resolvedCustomer = null;
                          _showCreateNewCustomer = false;
                          ref.read(customerCodeLookupControllerProvider.notifier).clear();
                        }),
                      ),
              ),
              if (lookupState.isLoading) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              // Both paths are offered up front — Admin doesn't have to
              // search and hit a "not found" first to discover they can
              // create a new customer here.
              if (_resolvedCustomer == null)
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
                      Expanded(child: Text(_resolvedCustomer!.name)),
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
                if (notFound) ...[
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
