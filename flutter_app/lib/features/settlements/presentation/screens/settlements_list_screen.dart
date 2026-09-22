import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/permission.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/settlement_providers.dart';

/// Admin sees every settlement sheet; a Delivery Agent or Salesman sees
/// only the sheets they're assigned to — same query for everyone, the
/// backend does the scoping (see SettlementService.list_sheets).
class SettlementsListScreen extends ConsumerStatefulWidget {
  const SettlementsListScreen({super.key});

  @override
  ConsumerState<SettlementsListScreen> createState() => _SettlementsListScreenState();
}

class _SettlementsListScreenState extends ConsumerState<SettlementsListScreen> {
  String? _statusFilter;

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) => Formatters.roleLabel(status);

  @override
  Widget build(BuildContext context) {
    final sheetsAsync = ref.watch(settlementsListProvider(_statusFilter));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canCreate = user != null && (user.isAdmin || user.hasPermission(Permission.settlementsManage));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Settlements', style: AppTextStyles.heading1),
              const Spacer(),
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => context.go('/settlements/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Sheet'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _statusFilter == null, onTap: () => setState(() => _statusFilter = null)),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Draft',
                  selected: _statusFilter == 'draft',
                  onTap: () => setState(() => _statusFilter = 'draft'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'In Progress',
                  selected: _statusFilter == 'in_progress',
                  onTap: () => setState(() => _statusFilter = 'in_progress'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Completed',
                  selected: _statusFilter == 'completed',
                  onTap: () => setState(() => _statusFilter = 'completed'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sheetsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(settlementsListProvider(_statusFilter)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(
                    message: 'No settlement sheets yet.',
                    icon: Icons.fact_check_outlined,
                  );
                }
                return ListView.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final sheet = page.items[i];
                    final summary = sheet.summary;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/settlements/${sheet.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(sheet.sheetNo, style: AppTextStyles.heading3)),
                                  _StatusPill(label: _statusLabel(sheet.status), color: _statusColor(sheet.status)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${Formatters.date(sheet.sheetDate)} · ${sheet.deliveryAgentName} · ${sheet.salesmanName}',
                                style: AppTextStyles.bodySecondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _countChip('${summary.totalItems} customers', AppColors.textSecondary),
                                  if (summary.pending > 0) _countChip('${summary.pending} pending', AppColors.warning),
                                  _countChip('Collected: ${Formatters.currency(summary.totalCollected)}', AppColors.success),
                                  if (summary.totalCreditOutstanding > 0)
                                    _countChip(
                                      'Credit due: ${Formatters.currency(summary.totalCreditOutstanding)}',
                                      AppColors.error,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _countChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
