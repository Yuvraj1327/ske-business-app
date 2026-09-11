import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import '../providers/return_providers.dart';

/// Create a return against a specific sale's line items. The "returnable"
/// quantity shown per line is a client-side preview (sold qty minus already
/// returned, from prior completed returns) — the backend re-validates this
/// authoritatively and is the real source of truth (see
/// app/services/sales_return_service.py).
class CreateReturnScreen extends ConsumerStatefulWidget {
  const CreateReturnScreen({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends ConsumerState<CreateReturnScreen> {
  final Map<String, TextEditingController> _qtyControllers = {};
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _reasonController.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String saleItemId) {
    return _qtyControllers.putIfAbsent(saleItemId, () => TextEditingController(text: '0'));
  }

  Future<void> _submit() async {
    final items = <({String saleItemId, double quantity})>[];
    for (final entry in _qtyControllers.entries) {
      final qty = double.tryParse(entry.value.text.trim()) ?? 0;
      if (qty > 0) {
        items.add((saleItemId: entry.key, quantity: qty));
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a quantity to return for at least one item.')));
      return;
    }

    final result = await ref.read(returnMutationControllerProvider.notifier).createReturn(
          saleId: widget.saleId,
          items: items,
          reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        );

    if (!mounted) return;
    if (result != null) {
      ref.invalidate(saleDetailProvider(widget.saleId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return recorded.')));
      context.go('/sales/${widget.saleId}');
    } else {
      final state = ref.read(returnMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleDetailProvider(widget.saleId));
    final priorReturnsAsync = ref.watch(saleReturnsProvider(widget.saleId));
    final mutationState = ref.watch(returnMutationControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: saleAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(failure: e is Failure ? e : Failure.unknown(e.toString())),
        data: (sale) {
          final alreadyReturnedByItem = <String, double>{};
          priorReturnsAsync.whenData((page) {
            for (final ret in page.items) {
              for (final item in ret.items) {
                alreadyReturnedByItem[item.saleItemId] = (alreadyReturnedByItem[item.saleItemId] ?? 0) + item.quantity;
              }
            }
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create Return', style: AppTextStyles.heading1),
              Text('${sale.invoice?.invoiceNumber ?? 'Sale'} · ${sale.customerName}', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...sale.items.map((item) {
                        final alreadyReturned = alreadyReturnedByItem[item.id] ?? 0;
                        final returnable = item.quantity - alreadyReturned;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: AppTextStyles.body),
                                      Text(
                                        'Sold: ${item.quantity} · Returnable: $returnable',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _controllerFor(item.id),
                                    enabled: returnable > 0,
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Reason (optional)', controller: _reasonController, maxLines: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(label: 'Submit Return', isLoading: mutationState.isLoading, onPressed: _submit),
            ],
          );
        },
      ),
    );
  }
}
