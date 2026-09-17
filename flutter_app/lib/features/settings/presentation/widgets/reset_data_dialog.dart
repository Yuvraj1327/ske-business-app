import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../providers/admin_providers.dart';

/// Settings -> Reset Data flow: Warning -> Enter Admin Password -> Verify ->
/// Reset. Everything happens inside one dialog (two internal steps) rather
/// than chaining separate dialogs, so there's exactly one place managing
/// the flow's state. The actual deletion and password verification both
/// happen server-side (see POST /admin/reset-data) — this dialog only
/// collects the password and displays the result; it never decides
/// success/failure itself.
Future<void> showResetDataDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _ResetDataDialog(),
  );
}

enum _ResetDataStep { warning, password, success }

class _ResetDataDialog extends ConsumerStatefulWidget {
  const _ResetDataDialog();

  @override
  ConsumerState<_ResetDataDialog> createState() => _ResetDataDialogState();
}

class _ResetDataDialogState extends ConsumerState<_ResetDataDialog> {
  _ResetDataStep _step = _ResetDataStep.warning;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Enter your password to continue.');
      return;
    }
    setState(() => _errorMessage = null);

    // No reset happens unless this call succeeds — a wrong password (or any
    // other failure) surfaces here and the dialog stays on this step with
    // nothing touched server-side.
    final message = await ref.read(resetDataControllerProvider.notifier).resetData(password);

    if (!mounted) return;
    if (message != null) {
      setState(() {
        _step = _ResetDataStep.success;
        _successMessage = message;
      });
    } else {
      final state = ref.read(resetDataControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      setState(() => _errorMessage = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(resetDataControllerProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _step == _ResetDataStep.success ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: _step == _ResetDataStep.success ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 10),
          Text(_step == _ResetDataStep.success ? 'Data Reset Complete' : 'Reset Business Data'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: switch (_step) {
          _ResetDataStep.warning => _buildWarningStep(),
          _ResetDataStep.password => _buildPasswordStep(mutationState.isLoading),
          _ResetDataStep.success => _buildSuccessStep(),
        },
      ),
      actions: switch (_step) {
        _ResetDataStep.warning => [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => setState(() => _step = _ResetDataStep.password),
              child: const Text('Continue'),
            ),
          ],
        _ResetDataStep.password => [
            TextButton(
              onPressed: mutationState.isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: mutationState.isLoading ? null : _submitPassword,
              child: mutationState.isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify & Reset'),
            ),
          ],
        _ResetDataStep.success => [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
      },
    );
  }

  Widget _buildWarningStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This permanently deletes all business/test data:',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 10),
        ..._bulletPoints([
          'Customers',
          'Sales, invoices and sale line items',
          'Payments received and cheque records',
          'Cash / UPI / Bank transactions',
          'Expenses',
          'Imported Excel files and import history',
          'Picklists and delivery records',
        ]),
        const SizedBox(height: 12),
        const Text(
          'Your admin account, all user accounts, roles, permissions, and products are NOT affected.',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 12),
        Text(
          'This cannot be undone. You will be asked to enter your password to confirm.',
          style: AppTextStyles.body.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter your admin password to confirm this reset.', style: AppTextStyles.body),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !isLoading,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => isLoading ? null : _submitPassword(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_successMessage ?? 'Business data has been reset.', style: AppTextStyles.body),
      ],
    );
  }

  List<Widget> _bulletPoints(List<String> items) {
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: AppTextStyles.bodySecondary),
                Expanded(child: Text(item, style: AppTextStyles.bodySecondary)),
              ],
            ),
          ),
        )
        .toList();
  }
}
