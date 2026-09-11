import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/customer_models.dart';
import '../providers/customer_providers.dart';

Future<bool?> showCustomerFormDialog(BuildContext context, {Customer? existingCustomer}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _CustomerFormDialog(existingCustomer: existingCustomer),
  );
}

class _CustomerFormDialog extends ConsumerStatefulWidget {
  const _CustomerFormDialog({this.existingCustomer});

  final Customer? existingCustomer;

  @override
  ConsumerState<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _gstController;

  bool get _isEditing => widget.existingCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCustomer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _gstController = TextEditingController(text: c?.gstNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(customerMutationControllerProvider.notifier);
    final success = _isEditing
        ? await controller.updateCustomer(
            id: widget.existingCustomer!.id,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            gstNumber: _gstController.text.trim(),
          )
        : await controller.createCustomer(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
          );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(customerMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(customerMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
      content: SizedBox(
        width: 420,
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
                AppTextField(
                  label: 'Phone',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email (optional)',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Address (optional)',
                  controller: _addressController,
                  maxLines: 2,
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'GST Number (optional)',
                  controller: _gstController,
                  enabled: !isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: _isEditing ? 'Save Changes' : 'Create Customer',
          isLoading: isSubmitting,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
