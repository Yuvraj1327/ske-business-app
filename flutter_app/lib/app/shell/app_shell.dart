import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/permissions/permission.dart';
import '../../core/permissions/permission_provider.dart';
import '../../features/auth/domain/app_user.dart';
import 'company_logo_mark.dart';

class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  final String? requiredPermission;

  const _NavItem({required this.path, required this.label, required this.icon, this.requiredPermission});
}

/// BOTTOM NAV (mobile only) — the handful of things both Admin and
/// Salesman reach for most often. Deliberately short: a bottom bar with
/// 10+ destinations stops being usable, which is why the full feature list
/// lives in the sidebar/drawer instead (see _allSidebarNavItems below).
const _bottomNavItems = [
  _NavItem(path: '/dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined),
  _NavItem(
    path: '/customers',
    label: 'Customers',
    icon: Icons.people_alt_outlined,
    requiredPermission: Permission.customersViewAssigned, // service layer widens this to view_all/admin
  ),
  _NavItem(path: '/sales', label: 'Sales', icon: Icons.point_of_sale_outlined, requiredPermission: Permission.salesViewAssigned),
  _NavItem(path: '/payments', label: 'Payments', icon: Icons.payments_outlined, requiredPermission: Permission.paymentsCreate),
  _NavItem(path: '/reports', label: 'Reports', icon: Icons.bar_chart_outlined, requiredPermission: Permission.reportsView),
];

/// SIDEBAR (nav rail on wide screens, drawer on narrow) — every feature,
/// shown directly with no "More" overflow. Same set of routes as before,
/// nothing removed.
const _allSidebarNavItems = [
  _NavItem(path: '/dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined),
  _NavItem(
    path: '/customers',
    label: 'Customers',
    icon: Icons.people_alt_outlined,
    requiredPermission: Permission.customersViewAssigned,
  ),
  _NavItem(path: '/products', label: 'Products', icon: Icons.inventory_2_outlined, requiredPermission: Permission.productsManage),
  _NavItem(path: '/sales', label: 'Sales', icon: Icons.point_of_sale_outlined, requiredPermission: Permission.salesViewAssigned),
  _NavItem(path: '/payments', label: 'Payments', icon: Icons.payments_outlined, requiredPermission: Permission.paymentsCreate),
  _NavItem(
    path: '/transactions',
    label: 'Cash / UPI / Bank',
    icon: Icons.account_balance_wallet_outlined,
    requiredPermission: Permission.transactionsManage,
  ),
  _NavItem(path: '/returns', label: 'Sales Returns', icon: Icons.assignment_return_outlined, requiredPermission: Permission.returnsCreate),
  _NavItem(path: '/expenses', label: 'Expenses', icon: Icons.receipt_long_outlined, requiredPermission: Permission.expensesManage),
  _NavItem(path: '/salesmen', label: 'Salesmen', icon: Icons.badge_outlined, requiredPermission: Permission.salesmenManage),
  _NavItem(path: '/reports', label: 'Reports', icon: Icons.bar_chart_outlined, requiredPermission: Permission.reportsView),
  _NavItem(path: '/imports', label: 'Excel Import', icon: Icons.upload_file_outlined, requiredPermission: Permission.importsManage),
  _NavItem(path: '/picklists', label: 'Picklists', icon: Icons.checklist_rtl_outlined, requiredPermission: Permission.picklistsViewAssigned),
  // Settlement Sheet — separate sidebar entry, visible to Admin, Salesman
  // and Delivery Agent alike (all three hold settlements.view_assigned or
  // settlements.manage); what each of them can actually do once inside is
  // gated screen-by-screen (see SettlementDetailScreen).
  _NavItem(
    path: '/settlements',
    label: 'Settlements',
    icon: Icons.fact_check_outlined,
    requiredPermission: Permission.settlementsViewAssigned,
  ),
  _NavItem(path: '/users', label: 'Users', icon: Icons.people_outline, requiredPermission: Permission.usersManage),
  _NavItem(
    path: '/roles',
    label: 'Roles & Permissions',
    icon: Icons.admin_panel_settings_outlined,
    requiredPermission: Permission.rolesManage,
  ),
];

/// Wraps every authenticated screen with a persistent sidebar (rail on wide
/// screens, drawer on narrow) showing ALL features directly, a bottom nav
/// on mobile for quick access to the 5 most-used ones, and a shared top bar
/// with Settings — all filtered by the logged-in user's permissions exactly
/// as before. This is a UX convenience; the real enforcement is
/// server-side, so even a direct deep-link to a hidden route still has its
/// underlying API calls rejected.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  bool _isVisible(WidgetRef ref, AppUser? user, String? requiredPermission) {
    if (requiredPermission == null) return true;
    if (user == null) return false;
    if (user.isAdmin) return true;
    return ref.watch(hasPermissionProvider(requiredPermission));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    final visibleSidebar = _allSidebarNavItems.where((item) => _isVisible(ref, user, item.requiredPermission)).toList();
    final visibleBottom = _bottomNavItems.where((item) => _isVisible(ref, user, item.requiredPermission)).toList();

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final sidebarSelectedIndex = visibleSidebar.indexWhere((item) => item.path == currentPath);
    final bottomSelectedIndex = visibleBottom.indexWhere((item) => item.path == currentPath);

    final currentTitle = sidebarSelectedIndex >= 0
        ? visibleSidebar[sidebarSelectedIndex].label
        : currentPath == '/settings'
            ? 'Settings'
            : 'Sai Krishna Enterprises';

    final topBar = AppBar(
      title: Text(currentTitle),
      automaticallyImplyLeading: !isWide,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => context.go('/settings'),
        ),
        const SizedBox(width: 4),
      ],
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: sidebarSelectedIndex < 0 ? 0 : sidebarSelectedIndex,
              onDestinationSelected: (index) => context.go(visibleSidebar[index].path),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CompanyLogoMark(),
              ),
              destinations: visibleSidebar
                  .map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  topBar,
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: topBar,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: CompanyLogoMark(size: 44, showWordmark: true),
              ),
              const Divider(height: 1),
              ...visibleSidebar.map(
                (item) => ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  selected: item.path == currentPath,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(item.path);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                selected: currentPath == '/settings',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/settings');
                },
              ),
            ],
          ),
        ),
      ),
      // Quick-access surface for the most common destinations — the full
      // feature list stays in the drawer (opened via the app bar's leading
      // hamburger icon); nothing is removed, just not duplicated here.
      bottomNavigationBar: visibleBottom.length < 2
          ? null
          : NavigationBar(
              selectedIndex: bottomSelectedIndex < 0 ? 0 : bottomSelectedIndex,
              onDestinationSelected: (index) => context.go(visibleBottom[index].path),
              destinations: visibleBottom
                  .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
                  .toList(),
            ),
      body: child,
    );
  }
}
