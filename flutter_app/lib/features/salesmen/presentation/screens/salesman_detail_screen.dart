import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../domain/salesman_models.dart';
import '../providers/salesman_providers.dart';

class SalesmanDetailScreen extends ConsumerStatefulWidget {
  const SalesmanDetailScreen({super.key, required this.salesmanId});

  final String salesmanId;

  @override
  ConsumerState<SalesmanDetailScreen> createState() => _SalesmanDetailScreenState();
}

class _SalesmanDetailScreenState extends ConsumerState<SalesmanDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showAssignCustomerDialog() async {
    final customersAsync = ref.read(customersListProvider);
    final customers = customersAsync.valueOrNull?.items ?? [];
    if (customers.isEmpty) return;

    String? selectedCustomerId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Assign Customer'),
          content: DropdownButtonFormField<String>(
            value: selectedCustomerId,
            hint: const Text('Select a customer'),
            items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setDialogState(() => selectedCustomerId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedCustomerId == null
                  ? null
                  : () async {
                      final success = await ref
                          .read(salesmanMutationControllerProvider.notifier)
                          .assignCustomer(widget.salesmanId, selectedCustomerId!);
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      if (!success && mounted) {
                        final state = ref.read(salesmanMutationControllerProvider);
                        final failure = state.hasError ? state.error as Failure : Failure.unknown();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
                      }
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign Task'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(label: 'Title', controller: titleController),
              const SizedBox(height: 12),
              AppTextField(label: 'Description (optional)', controller: descController, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              await ref.read(salesmanMutationControllerProvider.notifier).createTask(
                    salesmanId: widget.salesmanId,
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final performanceAsync = ref.watch(salesmanPerformanceProvider(widget.salesmanId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: performanceAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          failure: e is Failure ? e : Failure.unknown(e.toString()),
          onRetry: () => ref.invalidate(salesmanPerformanceProvider(widget.salesmanId)),
        ),
        data: (performance) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(performance.salesmanName, style: AppTextStyles.heading1),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [Tab(text: 'Performance'), Tab(text: 'Customers'), Tab(text: 'Tasks')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PerformanceTab(performance: performance),
                    _CustomersTab(salesmanId: widget.salesmanId, onAssign: _showAssignCustomerDialog),
                    _TasksTab(salesmanId: widget.salesmanId, onAddTask: _showAddTaskDialog),
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

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({required this.performance});
  final SalesmanPerformance performance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: [
          _statCard(context, 'Assigned Customers', '${performance.customersCount}', Icons.people_outline),
          _statCard(context, 'Sales', '${performance.salesCount}', Icons.point_of_sale_outlined),
          _statCard(context, 'Sales Total', Formatters.currency(performance.salesTotal), Icons.payments_outlined),
          _statCard(context, 'Outstanding', Formatters.currency(performance.outstandingTotal), Icons.hourglass_bottom_outlined),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.heading2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _CustomersTab extends ConsumerWidget {
  const _CustomersTab({required this.salesmanId, required this.onAssign});
  final String salesmanId;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(salesmanCustomersProvider(salesmanId));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Assign Customer'), onPressed: onAssign),
        ),
        Expanded(
          child: customersAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
            data: (page) {
              if (page.items.isEmpty) {
                return const EmptyStateView(message: 'No customers assigned yet.', icon: Icons.people_outline);
              }
              return ListView.separated(
                itemCount: page.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => ListTile(title: Text(page.items[i].name), subtitle: Text(page.items[i].phone ?? '—')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.salesmanId, required this.onAddTask});
  final String salesmanId;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(salesmanTasksProvider(salesmanId));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Assign Task'), onPressed: onAddTask),
        ),
        Expanded(
          child: tasksAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
            data: (page) {
              if (page.items.isEmpty) {
                return const EmptyStateView(message: 'No tasks assigned yet.', icon: Icons.checklist_outlined);
              }
              return ListView.separated(
                itemCount: page.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final task = page.items[i];
                  return ListTile(
                    title: Text(task.title),
                    subtitle: Text(task.dueDate != null ? 'Due ${Formatters.date(task.dueDate!)}' : (task.description ?? '')),
                    trailing: StatusBadge(label: task.status.replaceAll('_', ' '), color: _taskStatusColor(task.status)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _taskStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.info;
    }
  }
}
