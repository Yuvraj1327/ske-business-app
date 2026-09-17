import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/transaction_providers.dart';

Future<bool?> showTransactionFormDialog(BuildContext context) {
  return showDialog<bool>(context: context, builder: (_) => const _TransactionFormDialog());
}

class _TransactionFormDialog extends ConsumerStatefulWidget {
  const _TransactionFormDialog();

  @override
  ConsumerState<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends ConsumerState<_TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'cash';
  String _direction = 'in';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());

    final success = await ref.read(transactionMutationControllerProvider.notifier).createTransaction(
          transactionType: _type,
          direction: _direction,
          amount: amount,
          referenceNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(transactionMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(transactionMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    return AlertDialog(
      title: const Text('Add Transaction'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Type', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Cash')),
                      ButtonSegment(value: 'upi', label: Text('UPI')),
                      ButtonSegment(value: 'bank', label: Text('Bank')),
                    ],
                    selected: {_type},
                    onSelectionChanged: isSubmitting ? null : (s) => setState(() => _type = s.first),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Direction', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'in', label: Text('Cash In')),
                    ButtonSegment(value: 'out', label: Text('Cash Out')),
                  ],
                  selected: {_direction},
                  onSelectionChanged: isSubmitting ? null : (s) => setState(() => _direction = s.first),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Amount',
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.positiveNumber(v, fieldName: 'Amount'),
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                AppTextField(label: 'Note (optional)', controller: _noteController, maxLines: 2, enabled: !isSubmitting),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        AppButton(label: 'Add Transaction', isLoading: isSubmitting, expand: false, onPressed: _submit),
      ],
    );
  }
}
