import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/product_models.dart';
import '../providers/product_providers.dart';

Future<bool?> showProductFormDialog(BuildContext context, {Product? existingProduct}) {
  return showDialog<bool>(context: context, builder: (_) => _ProductFormDialog(existingProduct: existingProduct));
}

class _ProductFormDialog extends ConsumerStatefulWidget {
  const _ProductFormDialog({this.existingProduct});

  final Product? existingProduct;

  @override
  ConsumerState<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _unitController = TextEditingController(text: p?.unit ?? 'pcs');
    _priceController = TextEditingController(text: p != null ? p.defaultPrice.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.parse(_priceController.text.trim());
    final controller = ref.read(productMutationControllerProvider.notifier);

    final success = _isEditing
        ? await controller.updateProduct(
            id: widget.existingProduct!.id,
            name: _nameController.text.trim(),
            sku: _skuController.text.trim(),
            unit: _unitController.text.trim(),
            defaultPrice: price,
          )
        : await controller.createProduct(
            name: _nameController.text.trim(),
            sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
            unit: _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim(),
            defaultPrice: price,
          );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(productMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(productMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Name',
                  controller: _nameController,
                  validator: (v) => Validators.required(v, fieldName: 'Name'),
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                AppTextField(label: 'SKU (optional)', controller: _skuController, enabled: !isSubmitting),
                const SizedBox(height: 14),
                AppTextField(label: 'Unit (e.g. pcs, kg)', controller: _unitController, enabled: !isSubmitting),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Default Price',
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.positiveNumber(v, fieldName: 'Price'),
                  enabled: !isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        AppButton(
          label: _isEditing ? 'Save Changes' : 'Create Product',
          isLoading: isSubmitting,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
