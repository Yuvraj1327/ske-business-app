import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../payments/presentation/providers/payment_providers.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_form_dialog.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: customerAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(customerDetailProvider(widget.customerId)),
        ),
        data: (customer) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(customer.name, style: AppTextStyles.heading1)),
                  StatusBadge(
                    label: customer.isActive ? 'Active' : 'Inactive',
                    color: customer.isActive ? AppColors.success : AppColors.statusCancelled,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showCustomerFormDialog(context, existingCustomer: customer),
                  ),
                ],
              ),
              Text(customer.phone ?? customer.email ?? '—', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Sales'),
                  Tab(text: 'Payments'),
                  Tab(text: 'Ledger'),
                  Tab(text: 'Outstanding'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SalesTab(customerId: widget.customerId),
                    _PaymentsTab(customerId: widget.customerId),
                    _LedgerTab(customerId: widget.customerId),
                    _OutstandingTab(customerId: widget.customerId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(customerSalesProvider(customerId));
    return salesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (page) {
        if (page.items.isEmpty) {
          return const EmptyStateView(message: 'No sales for this customer yet.', icon: Icons.point_of_sale_outlined);
        }
        return ListView.separated(
          itemCount: page.items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final sale = page.items[i];
            return ListTile(
              title: Text(sale.invoiceNumber ?? 'Sale on ${Formatters.date(sale.saleDate)}'),
              subtitle: Text(Formatters.date(sale.saleDate)),
              trailing: Text(Formatters.currency(sale.totalAmount)),
              onTap: () => context.go('/sales/${sale.id}'),
            );
          },
        );
      },
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(customerPaymentsProvider(customerId));
    return paymentsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (page) {
        if (page.items.isEmpty) {
          return const EmptyStateView(message: 'No payments for this customer yet.', icon: Icons.payments_outlined);
        }
        return ListView.separated(
          itemCount: page.items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final payment = page.items[i];
            return ListTile(
              title: Text(payment.paymentMethod.replaceAll('_', ' ').toUpperCase()),
              subtitle: Text(Formatters.date(payment.paymentDate)),
              trailing: Text(Formatters.currency(payment.amount)),
            );
          },
        );
      },
    );
  }
}

class _LedgerTab extends ConsumerWidget {
  const _LedgerTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(customerLedgerProvider(customerId));
    return ledgerAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (ledger) {
        if (ledger.entries.isEmpty) {
          return const EmptyStateView(message: 'No ledger activity yet.', icon: Icons.receipt_long_outlined);
        }
        return ListView.separated(
          itemCount: ledger.entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final entry = ledger.entries[i];
            final isDebit = entry.debit > 0;
            return ListTile(
              title: Text(entry.referenceLabel),
              subtitle: Text(Formatters.date(entry.entryDate)),
              trailing: Text(
                isDebit ? '+${Formatters.currency(entry.debit)}' : '−${Formatters.currency(entry.credit)}',
                style: TextStyle(color: isDebit ? AppColors.error : AppColors.success, fontWeight: FontWeight.w600),
              ),
            );
          },
        );
      },
    );
  }
}

class _OutstandingTab extends ConsumerWidget {
  const _OutstandingTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstandingAsync = ref.watch(customerOutstandingProvider(customerId));
    return outstandingAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
      data: (outstanding) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Total Sales', outstanding.totalSales),
              _row('Total Paid', outstanding.totalPaid),
              _row('Total Returned', outstanding.totalReturned),
              const Divider(),
              _row('Outstanding', outstanding.outstanding, bold: true, color: AppColors.error),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, double value, {bool bold = false, Color? color}) {
    final style = (bold ? AppTextStyles.heading2 : AppTextStyles.body).copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.bodySecondary),
        Text(Formatters.currency(value), style: style),
      ]),
    );
  }
}
