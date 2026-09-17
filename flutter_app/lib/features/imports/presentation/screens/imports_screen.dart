import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../picklists/presentation/providers/picklist_providers.dart';
import '../../domain/import_models.dart';
import '../providers/import_providers.dart';

/// Excel Import screen: pick a customers/products/picklist .xlsx file,
/// upload it (processing happens server-side in the background — see
/// app/services/import_service.py), and watch job status/row-level results
/// in the history list below. For a picklist, a Delivery Agent must be
/// selected first — that's who the resulting deliveries get assigned to.
class ImportsScreen extends ConsumerStatefulWidget {
  const ImportsScreen({super.key});

  @override
  ConsumerState<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends ConsumerState<ImportsScreen> {
  String _entityType = 'customers';
  String? _selectedDeliveryAgentId;

  Future<void> _pickAndUpload() async {
    if (_entityType == 'picklists' && _selectedDeliveryAgentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Delivery Agent before uploading a picklist.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the selected file.')));
      return;
    }

    final job = await ref.read(importMutationControllerProvider.notifier).uploadFile(
          entityType: _entityType,
          fileBytes: file.bytes!,
          fileName: file.name,
          deliveryAgentId: _entityType == 'picklists' ? _selectedDeliveryAgentId : null,
        );

    if (!mounted) return;
    if (job != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload started — processing in the background.')));
      setState(() => _selectedDeliveryAgentId = null);
    } else {
      final state = ref.read(importMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _showFailedRows(ImportJob job) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, _) {
              final rowsAsync = ref.watch(importJobRowsProvider(job.id));
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Failed Rows — ${job.fileName}', style: AppTextStyles.heading3),
                    const Divider(),
                    Expanded(
                      child: rowsAsync.when(
                        loading: () => const LoadingView(),
                        error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
                        data: (page) {
                          if (page.items.isEmpty) {
                            return const EmptyStateView(message: 'No failed rows.', icon: Icons.check_circle_outline);
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: page.items.length,
                            itemBuilder: (context, i) {
                              final row = page.items[i];
                              return ListTile(
                                dense: true,
                                leading: Text('Row ${row.rowNumber}'),
                                title: Text(row.errorMessage ?? 'Unknown error', style: const TextStyle(color: AppColors.error)),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'processing':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(importJobsListProvider);
    final mutationState = ref.watch(importMutationControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Excel Import', style: AppTextStyles.heading1),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import Type', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'customers', label: Text('Customers')),
                      ButtonSegment(value: 'products', label: Text('Products')),
                      ButtonSegment(value: 'picklists', label: Text('Picklist')),
                    ],
                    selected: {_entityType},
                    onSelectionChanged: (s) => setState(() {
                      _entityType = s.first;
                      _selectedDeliveryAgentId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    switch (_entityType) {
                      'customers' => 'Required column: name. Optional: phone, email, address, gst_number.',
                      'products' => 'Required columns: name, default_price. Optional: sku, unit.',
                      _ => 'Accepts the delivery agent\'s picklist file exactly as exported: Picklist No / '
                          'Delivery agent / PSR Route header, then No., Invoice Number, Customer Code, '
                          'Customer Name, Sales man, Amount Payable columns.',
                    },
                    style: AppTextStyles.caption,
                  ),
                  if (_entityType == 'picklists') ...[
                    const SizedBox(height: 14),
                    Text('Delivery Agent', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 6),
                    Consumer(
                      builder: (context, ref, _) {
                        final agentsAsync = ref.watch(deliveryAgentsProvider);
                        return agentsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => const Text('Could not load delivery agents'),
                          data: (agents) {
                            if (agents.isEmpty) {
                              return const Text(
                                'No delivery agents found. Create one from Users first.',
                                style: AppTextStyles.caption,
                              );
                            }
                            return DropdownButtonFormField<String>(
                              value: _selectedDeliveryAgentId,
                              hint: const Text('Select the agent this picklist belongs to'),
                              items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.fullName))).toList(),
                              onChanged: (v) => setState(() => _selectedDeliveryAgentId = v),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(mutationState.isLoading ? 'Uploading...' : 'Choose .xlsx File'),
                    onPressed: mutationState.isLoading ? null : _pickAndUpload,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Import History', style: AppTextStyles.heading3),
          const SizedBox(height: 8),
          Expanded(
            child: jobsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                failure: e is Failure ? e : Failure.unknown(e.toString()),
                onRetry: () => ref.invalidate(importJobsListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const EmptyStateView(message: 'No imports yet.', icon: Icons.upload_file_outlined);
                }
                return ListView.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final job = page.items[i];
                    return ListTile(
                      title: Text(job.fileName),
                      subtitle: Text(
                        '${job.entityType} · ${Formatters.dateTime(job.createdAt)}'
                        '${job.totalRows != null ? ' · ${job.successRows}/${job.totalRows} succeeded' : ''}',
                      ),
                      trailing: StatusBadge(label: job.status, color: _statusColor(job.status)),
                      onTap: job.failedRows > 0 ? () => _showFailedRows(job) : null,
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
}
