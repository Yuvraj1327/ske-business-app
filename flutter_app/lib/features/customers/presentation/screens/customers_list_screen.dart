import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_form_dialog.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final filter = ref.watch(customersFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Customers', style: AppTextStyles.heading1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Customer'),
                onPressed: () => showCustomerFormDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Search by name or phone...', prefixIcon: Icon(Icons.search)),
            onSubmitted: (value) {
              ref.read(customersFilterProvider.notifier).state = filter.copyWith(search: value, page: 1);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: customersAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(customersListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(message: 'No customers found.', icon: Icons.people_outline);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final customer = page.items[index];
                          return ListTile(
                            title: Text(customer.name, overflow: TextOverflow.ellipsis),
                            subtitle: Text(customer.phone ?? customer.email ?? '—', overflow: TextOverflow.ellipsis),
                            trailing: StatusBadge(
                              label: customer.isActive ? 'Active' : 'Inactive',
                              color: customer.isActive ? AppColors.success : AppColors.statusCancelled,
                            ),
                            onTap: () => context.go('/customers/${customer.id}'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${page.total} customer(s) · Page ${page.page} of ${page.totalPages}',
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: page.page > 1
                                  ? () => ref.read(customersFilterProvider.notifier).state =
                                      filter.copyWith(page: page.page - 1)
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: page.hasNextPage
                                  ? () => ref.read(customersFilterProvider.notifier).state =
                                      filter.copyWith(page: page.page + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
