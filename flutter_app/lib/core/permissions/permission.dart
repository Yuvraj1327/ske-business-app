/// Mirrors the `permissions.key` values seeded in
/// database/migrations/001_initial_schema.sql. Kept as string constants
/// (not an enum) so new permissions added purely via backend data don't
/// require an app rebuild to be checked with `hasPermissionProvider`. This
/// class documents the known keys for autocomplete/typo-safety in code
/// that references them.
class Permission {
  Permission._();

  static const usersManage = 'users.manage';
  static const rolesManage = 'roles.manage';

  static const customersViewAll = 'customers.view_all';
  static const customersViewAssigned = 'customers.view_assigned';
  static const customersCreate = 'customers.create';
  static const customersEdit = 'customers.edit';

  static const productsManage = 'products.manage';

  static const salesCreate = 'sales.create';
  static const salesViewAll = 'sales.view_all';
  static const salesViewAssigned = 'sales.view_assigned';
  static const salesCancel = 'sales.cancel';

  static const invoicesView = 'invoices.view';

  static const paymentsCreate = 'payments.create';
  static const paymentsManageChequeStatus = 'payments.manage_cheque_status';

  static const returnsCreate = 'returns.create';

  static const transactionsManage = 'transactions.manage';
  static const expensesManage = 'expenses.manage';
  static const salesmenManage = 'salesmen.manage';
  static const reportsView = 'reports.view';
  static const importsManage = 'imports.manage';
  static const dashboardView = 'dashboard.view';
}
