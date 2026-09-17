import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_state.dart';
import '../core/permissions/permission.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/customers/presentation/screens/customer_detail_screen.dart';
import '../features/customers/presentation/screens/customers_list_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_shell_screen.dart';
import '../features/expenses/presentation/screens/expenses_list_screen.dart';
import '../features/imports/presentation/screens/imports_screen.dart';
import '../features/payments/presentation/screens/payments_list_screen.dart';
import '../features/payments/presentation/screens/record_payment_screen.dart';
import '../features/picklists/presentation/screens/picklist_detail_screen.dart';
import '../features/picklists/presentation/screens/picklists_list_screen.dart';
import '../features/products/presentation/screens/products_list_screen.dart';
import '../features/reports/presentation/screens/reports_hub_screen.dart';
import '../features/returns/presentation/screens/create_return_screen.dart';
import '../features/returns/presentation/screens/returns_list_screen.dart';
import '../features/roles/presentation/screens/roles_permissions_screen.dart';
import '../features/sales/presentation/screens/create_sale_screen.dart';
import '../features/sales/presentation/screens/sale_detail_screen.dart';
import '../features/sales/presentation/screens/sales_list_screen.dart';
import '../features/salesmen/presentation/screens/salesman_detail_screen.dart';
import '../features/salesmen/presentation/screens/salesmen_list_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/transactions/presentation/screens/transactions_list_screen.dart';
import '../features/users/presentation/screens/users_list_screen.dart';
import 'shell/app_shell.dart';

/// A tiny Listenable adapter so GoRouter can `refreshListenable` off a
/// Riverpod stream (auth state + resolved profile changes) and re-run its
/// `redirect` callback whenever either changes, without polling.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(supabaseAuthStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}

/// Wraps a screen with no page-transition animation — navigating between
/// features should switch instantly, not slide/fade. Data loading is a
/// separate, unrelated concern: each screen still shows its own small
/// LoadingView while ITS OWN provider is fetching (unchanged) — this only
/// removes the animated page transition chrome around that.
Page<void> _instant(Widget child) => NoTransitionPage(child: child);

/// Top-level list routes that require a specific permission to view.
/// Deep-linking to one of these without the permission redirects to
/// /dashboard — the actual data access is still enforced server-side
/// regardless of this check. Parameterized detail/create routes (e.g.
/// /sales/:id) intentionally aren't listed here: if a user can't see the
/// list they generally won't navigate to a detail page, and this guard is a
/// UX convenience, not the security boundary.
const _permissionGuardedRoutes = <String, String>{
  '/customers': Permission.customersViewAssigned,
  '/products': Permission.productsManage,
  '/sales': Permission.salesViewAssigned,
  '/payments': Permission.paymentsCreate,
  '/transactions': Permission.transactionsManage,
  '/returns': Permission.returnsCreate,
  '/expenses': Permission.expensesManage,
  '/salesmen': Permission.salesmenManage,
  '/reports': Permission.reportsView,
  '/imports': Permission.importsManage,
  '/picklists': Permission.picklistsViewAssigned,
  '/users': Permission.usersManage,
  '/roles': Permission.rolesManage,
};

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/dashboard';

      final requiredPermission = _permissionGuardedRoutes[state.matchedLocation];
      if (requiredPermission != null) {
        final AppUser? user = ref.read(currentUserProvider).valueOrNull;
        // While the profile is still loading, allow the route through —
        // AppShell's own permission-filtered nav will hide the link, and a
        // direct deep-link during the brief loading window is harmless since
        // the underlying API calls are the real enforcement point.
        if (user != null && !user.isAdmin && !user.hasPermission(requiredPermission)) {
          return '/dashboard';
        }
      }

      return null; // no redirect needed
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (context, state) => _instant(const LoginScreen())),

      // All authenticated screens share the same nav shell (rail/drawer +
      // top bar). ShellRoute keeps AppShell alive across navigation instead
      // of rebuilding it per page.
      ShellRoute(
        builder: (context, state, child) => AppShell(currentPath: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (context, state) => _instant(const DashboardShellScreen())),

          GoRoute(path: '/customers', pageBuilder: (context, state) => _instant(const CustomersListScreen())),
          GoRoute(
            path: '/customers/:id',
            pageBuilder: (context, state) => _instant(CustomerDetailScreen(customerId: state.pathParameters['id']!)),
          ),

          GoRoute(path: '/products', pageBuilder: (context, state) => _instant(const ProductsListScreen())),

          GoRoute(path: '/sales', pageBuilder: (context, state) => _instant(const SalesListScreen())),
          GoRoute(path: '/sales/new', pageBuilder: (context, state) => _instant(const CreateSaleScreen())),
          GoRoute(
            path: '/sales/:id',
            pageBuilder: (context, state) => _instant(SaleDetailScreen(saleId: state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/sales/:id/return',
            pageBuilder: (context, state) => _instant(CreateReturnScreen(saleId: state.pathParameters['id']!)),
          ),

          GoRoute(path: '/payments', pageBuilder: (context, state) => _instant(const PaymentsListScreen())),
          GoRoute(
            path: '/payments/new',
            pageBuilder: (context, state) => _instant(
              RecordPaymentScreen(
                initialCustomerId: state.uri.queryParameters['customerId'],
                initialSaleId: state.uri.queryParameters['saleId'],
              ),
            ),
          ),

          GoRoute(path: '/transactions', pageBuilder: (context, state) => _instant(const TransactionsListScreen())),
          GoRoute(path: '/returns', pageBuilder: (context, state) => _instant(const ReturnsListScreen())),
          GoRoute(path: '/expenses', pageBuilder: (context, state) => _instant(const ExpensesListScreen())),

          GoRoute(path: '/salesmen', pageBuilder: (context, state) => _instant(const SalesmenListScreen())),
          GoRoute(
            path: '/salesmen/:id',
            pageBuilder: (context, state) => _instant(SalesmanDetailScreen(salesmanId: state.pathParameters['id']!)),
          ),

          GoRoute(path: '/reports', pageBuilder: (context, state) => _instant(const ReportsHubScreen())),
          GoRoute(path: '/imports', pageBuilder: (context, state) => _instant(const ImportsScreen())),

          GoRoute(path: '/picklists', pageBuilder: (context, state) => _instant(const PicklistsListScreen())),
          GoRoute(
            path: '/picklists/:id',
            pageBuilder: (context, state) => _instant(PicklistDetailScreen(picklistId: state.pathParameters['id']!)),
          ),

          GoRoute(path: '/users', pageBuilder: (context, state) => _instant(const UsersListScreen())),
          GoRoute(path: '/roles', pageBuilder: (context, state) => _instant(const RolesPermissionsScreen())),

          // Settings is intentionally NOT in _permissionGuardedRoutes above —
          // it's account-level (theme, account info, logout), available to
          // every authenticated user regardless of role/permissions.
          GoRoute(path: '/settings', pageBuilder: (context, state) => _instant(const SettingsScreen())),
        ],
      ),
    ],
  );
});
