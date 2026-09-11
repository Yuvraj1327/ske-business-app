import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/expense_providers.dart';

Future<bool?> showExpenseFormDialog(BuildContext context) {
  return showDialog<bool>(context: context, builder: (_) => const _ExpenseFormDialog());
}

class _ExpenseFormDialog extends ConsumerStatefulWidget {
  const _ExpenseFormDialog();

  @override
  ConsumerState<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _categoryId;
  String? _paymentMethod; // null = not yet paid
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newCategoryController = TextEditingController();
  bool _addingCategory = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    final success = await ref.read(expenseMutationControllerProvider.notifier).createCategory(name);
    if (!mounted) return;
    if (success) {
      setState(() {
        _addingCategory = false;
        _newCategoryController.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a category.')));
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final success = await ref.read(expenseMutationControllerProvider.notifier).createExpense(
          categoryId: _categoryId!,
          amount: amount,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          paymentMethod: _paymentMethod,
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(expenseMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final mutationState = ref.watch(expenseMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    return AlertDialog(
      title: const Text('Add Expense'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const Text('Could not load categories'),
                  data: (categories) => Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _categoryId,
                          items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: isSubmitting ? null : (v) => setState(() => _categoryId = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'New category',
                        onPressed: isSubmitting ? null : () => setState(() => _addingCategory = !_addingCategory),
                      ),
                    ],
                  ),
                ),
                if (_addingCategory) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newCategoryController,
                          decoration: const InputDecoration(hintText: 'New category name'),
                        ),
                      ),
                      TextButton(onPressed: _createCategory, child: const Text('Add')),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Amount',
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.positiveNumber(v, fieldName: 'Amount'),
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                AppTextField(label: 'Description (optional)', controller: _descriptionController, maxLines: 2, enabled: !isSubmitting),
                const SizedBox(height: 14),
                Text('Paid via (optional)', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Not yet')),
                    ButtonSegment(value: 'cash', label: Text('Cash')),
                    ButtonSegment(value: 'upi', label: Text('UPI')),
                    ButtonSegment(value: 'bank', label: Text('Bank')),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: isSubmitting ? null : (s) => setState(() => _paymentMethod = s.first),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        AppButton(label: 'Add Expense', isLoading: isSubmitting, expand: false, onPressed: _submit),
      ],
    );
  }
}
