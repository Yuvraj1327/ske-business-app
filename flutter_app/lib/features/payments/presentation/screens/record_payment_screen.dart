import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../providers/payment_providers.dart';

/// Records a payment against a customer (optionally tied to a specific
/// sale, when navigated here from a sale's "Record Payment" button).
class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, this.initialCustomerId, this.initialSaleId});

  final String? initialCustomerId;
  final String? initialSaleId;

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _customerId;
  String _method = 'cash';
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  DateTime? _chequeDate;

  @override
  void initState() {
    super.initState();
    _customerId = widget.initialCustomerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _chequeNumberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _pickChequeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) setState(() => _chequeDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer.')));
      return;
    }
    if (_method == 'cheque' && _chequeDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cheque date.')));
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final payment = await ref.read(paymentMutationControllerProvider.notifier).createPayment(
          customerId: _customerId!,
          saleId: widget.initialSaleId,
          amount: amount,
          paymentMethod: _method,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          chequeNumber: _method == 'cheque' ? _chequeNumberController.text.trim() : null,
          chequeDate: _method == 'cheque' ? _chequeDate : null,
          bankName: _method == 'cheque' ? _bankNameController.text.trim() : null,
        );

    if (!mounted) return;
    if (payment != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded.')));
      context.pop();
    } else {
      final state = ref.read(paymentMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final mutationState = ref.watch(paymentMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Record Payment', style: AppTextStyles.heading1),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Customer', style: AppTextStyles.heading3),
                    const SizedBox(height: 8),
                    customersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('Could not load customers'),
                      data: (page) => DropdownButtonFormField<String>(
                        value: _customerId,
                        hint: const Text('Select a customer'),
                        items: page.items.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: widget.initialCustomerId != null
                            ? null // locked when arriving from a specific sale
                            : (value) => setState(() => _customerId = value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Amount',
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => Validators.positiveNumber(v, fieldName: 'Amount'),
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    const Text('Payment Method', style: AppTextStyles.heading3),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'cash', label: Text('Cash')),
                          ButtonSegment(value: 'upi', label: Text('UPI')),
                          ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
                          ButtonSegment(value: 'cheque', label: Text('Cheque')),
                        ],
                        selected: {_method},
                        onSelectionChanged: isSubmitting ? null : (s) => setState(() => _method = s.first),
                      ),
                    ),
                    if (_method == 'cheque') ...[
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Cheque Number',
                        controller: _chequeNumberController,
                        validator: (v) => Validators.required(v, fieldName: 'Cheque number'),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Bank Name',
                        controller: _bankNameController,
                        validator: (v) => Validators.required(v, fieldName: 'Bank name'),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_chequeDate == null ? 'Select cheque date' : 'Cheque date: ${_chequeDate!.toLocal()}'.split(' ').first),
                        trailing: const Icon(Icons.calendar_today, size: 18),
                        onTap: isSubmitting ? null : _pickChequeDate,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppTextField(label: 'Notes (optional)', controller: _notesController, maxLines: 2, enabled: !isSubmitting),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'Record Payment', isLoading: isSubmitting, onPressed: _submit),
        ],
      ),
    );
  }
}
