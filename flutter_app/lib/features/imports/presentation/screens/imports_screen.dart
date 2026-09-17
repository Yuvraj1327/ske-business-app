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
import '../../domain/import_models.dart';
import '../providers/import_providers.dart';

/// Excel Import screen: pick a customers/products .xlsx file, upload it
/// (processing happens server-side in the background — see
/// app/services/import_service.py), and watch job status/row-level results
/// in the history list below.
class ImportsScreen extends ConsumerStatefulWidget {
  const ImportsScreen({super.key});

  @override
  ConsumerState<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends ConsumerState<ImportsScreen> {
  String _entityType = 'customers';

  Future<void> _pickAndUpload() async {
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
        );

    if (!mounted) return;
    if (job != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload started — processing in the background.')));
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
                    Text('Failed Rows — ${job.fileName}', style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis),
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
                                title: Text(
                                  row.errorMessage ?? 'Unknown error',
                                  style: const TextStyle(color: AppColors.error),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
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
                    ],
                    selected: {_entityType},
                    onSelectionChanged: (s) => setState(() => _entityType = s.first),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _entityType == 'customers'
                        ? 'Required column: name. Optional: phone, email, address, gst_number.'
                        : 'Required columns: name, default_price. Optional: sku, unit.',
                    style: AppTextStyles.caption,
                  ),
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
                      title: Text(job.fileName, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${job.entityType} · ${Formatters.dateTime(job.createdAt)}'
                        '${job.totalRows != null ? ' · ${job.successRows}/${job.totalRows} succeeded' : ''}',
                        overflow: TextOverflow.ellipsis,
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
