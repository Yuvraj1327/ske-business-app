import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../roles/presentation/providers/role_providers.dart';
import '../../domain/managed_user.dart';
import '../providers/user_providers.dart';

/// Shows the add/edit user dialog. Returns true if a mutation succeeded
/// (caller can use this to refresh, though the list already auto-refreshes
/// via provider invalidation).
Future<bool?> showUserFormDialog(BuildContext context, {ManagedUser? existingUser}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _UserFormDialog(existingUser: existingUser),
  );
}

class _UserFormDialog extends ConsumerStatefulWidget {
  const _UserFormDialog({this.existingUser});

  final ManagedUser? existingUser;

  @override
  ConsumerState<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  String? _selectedRoleId;

  bool get _isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.existingUser?.fullName ?? '');
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: widget.existingUser?.phone ?? '');
    _selectedRoleId = widget.existingUser?.roleId;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) return;

    final controller = ref.read(userMutationControllerProvider.notifier);
    bool success;

    if (_isEditing) {
      success = await controller.updateUser(
        userId: widget.existingUser!.id,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        roleId: _selectedRoleId,
      );
    } else {
      success = await controller.createUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        roleId: _selectedRoleId!,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final state = ref.read(userMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesListProvider);
    final mutationState = ref.watch(userMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit User' : 'Add User'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  validator: (v) => Validators.required(v, fieldName: 'Full name'),
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                if (!_isEditing) ...[
                  AppTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Temporary Password',
                    controller: _passwordController,
                    obscureText: true,
                    validator: Validators.password,
                    enabled: !isSubmitting,
                    hintText: 'Shared with the user to log in',
                  ),
                  const SizedBox(height: 14),
                ],
                AppTextField(
                  label: 'Phone (optional)',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 14),
                Text('Role', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                rolesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const Text('Could not load roles'),
                  data: (roles) => DropdownButtonFormField<String>(
                    value: _selectedRoleId,
                    items: roles
                        .map((r) => DropdownMenuItem(value: r.id, child: Text(Formatters.roleLabel(r.name))))
                        .toList(),
                    onChanged: isSubmitting ? null : (value) => setState(() => _selectedRoleId = value),
                    validator: (v) => v == null ? 'Select a role' : null,
                  ),
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
          label: _isEditing ? 'Save Changes' : 'Create User',
          isLoading: isSubmitting,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
