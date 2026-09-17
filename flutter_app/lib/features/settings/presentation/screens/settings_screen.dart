import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/company_logo_mark.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/data/auth_repository.dart';

/// Settings — available to both Admin and Salesman/Delivery Agent alike
/// (not permission gated, since it's account-level rather than a business
/// feature). Covers account details, theme, terms, basic app info, and
/// logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You\'ll need to sign in again to access your account.',
      confirmLabel: 'Log Out',
    );
    if (confirmed) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  void _showTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'This is placeholder Terms & Conditions text for Sai Krishna '
            'Enterprises\' internal business management app. Replace this '
            'with your actual terms before distributing the app beyond '
            'internal testing.\n\n'
            'In summary: this app is for authorized staff use only, to '
            'manage customers, sales, payments, and related business '
            'records. Access is controlled by the roles and permissions '
            'configured by your administrator.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CompanyLogoMark(size: 40),
                const SizedBox(width: 12),
                Text('Settings', style: AppTextStyles.heading1),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Account Details',
              child: user == null
                  ? const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())
                  : Column(
                      children: [
                        _infoRow('Name', user.fullName),
                        _infoRow('Role', Formatters.roleLabel(user.roleName)),
                        _infoRow('Status', user.isActive ? 'Active' : 'Inactive'),
                        _infoRow('Permissions granted', '${user.permissions.length}'),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Appearance',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) => ref.read(themeModeProvider.notifier).setThemeMode(selection.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Currently using: ${_themeModeLabel(themeMode)}. This choice is saved on this device.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'App',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms & Conditions'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _showTermsDialog(context),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('App Version'),
                    trailing: Text('1.0.0', style: AppTextStyles.bodySecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () => _confirmLogout(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySecondary),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title!, style: AppTextStyles.heading3),
          ),
        ],
        Card(child: child),
      ],
    );
  }
}
