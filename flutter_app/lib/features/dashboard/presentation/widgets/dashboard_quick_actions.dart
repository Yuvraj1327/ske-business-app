import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/permissions/permission.dart';
import '../../../../core/permissions/permission_provider.dart';
import '../../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../../expenses/presentation/widgets/expense_form_dialog.dart';

/// Shortcut buttons to the 4 most common creation flows, reusing the exact
/// same navigation/dialog entry points as the Sales/Payments/Customers/
/// Expenses list screens — no new routes or forms. Hidden (not just
/// disabled) per-action when the user lacks the matching permission, same
/// convention as the rest of the app (server enforces it either way).
class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_QuickAction>[
      if (ref.watch(hasPermissionProvider(Permission.salesCreate)))
        _QuickAction(label: 'New Sale', icon: Icons.point_of_sale_outlined, onTap: () => context.go('/sales/new')),
      if (ref.watch(hasPermissionProvider(Permission.paymentsCreate)))
        _QuickAction(label: 'New Payment', icon: Icons.payments_outlined, onTap: () => context.go('/payments/new')),
      if (ref.watch(hasPermissionProvider(Permission.customersCreate)))
        _QuickAction(label: 'New Customer', icon: Icons.person_add_alt_1_outlined, onTap: () => showCustomerFormDialog(context)),
      if (ref.watch(hasPermissionProvider(Permission.expensesManage)))
        _QuickAction(label: 'New Expense', icon: Icons.receipt_long_outlined, onTap: () => showExpenseFormDialog(context)),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final action in actions) _QuickActionButton(action: action)],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.onTap});
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: action.onTap,
      icon: Icon(action.icon, size: 17, color: AppColors.primary),
      label: Text(action.label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
    );
  }
}
