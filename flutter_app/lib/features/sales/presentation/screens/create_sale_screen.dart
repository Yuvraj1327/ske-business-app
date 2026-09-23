import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/breakpoints.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../products/domain/product_models.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/sale_models.dart';
import '../providers/sale_providers.dart';

/// Create Sale: pick a customer, add one or more line items, apply an
/// optional overall discount, and submit. All totals shown here are a
/// client-side preview for UX only — the backend recalculates and is the
/// authoritative source (see app/services/sale_service.py).
class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  String? _selectedCustomerId;
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _lineDiscountController = TextEditingController(text: '0');
  final _overallDiscountController = TextEditingController(text: '0');

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _lineDiscountController.dispose();
    _overallDiscountController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_selectedProduct == null) return;
    final qty = double.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final lineDiscount = double.tryParse(_lineDiscountController.text.trim()) ?? 0;
    if (qty == null || qty <= 0 || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity and price.')),
      );
      return;
    }

    ref.read(draftSaleItemsProvider.notifier).addItem(
          DraftSaleItem(
            productId: _selectedProduct!.id,
            productName: _selectedProduct!.name,
            quantity: qty,
            unitPrice: price,
            lineDiscount: lineDiscount,
          ),
        );

    setState(() {
      _selectedProduct = null;
      _qtyController.text = '1';
      _priceController.clear();
      _lineDiscountController.text = '0';
    });
  }

  Future<void> _submit() async {
    final items = ref.read(draftSaleItemsProvider);
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer.')));
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.')));
      return;
    }

    final discount = double.tryParse(_overallDiscountController.text.trim()) ?? 0;
    final sale = await ref.read(saleMutationControllerProvider.notifier).createSale(
          customerId: _selectedCustomerId!,
          items: items,
          discountAmount: discount,
        );

    if (!mounted) return;

    if (sale != null) {
      ref.read(draftSaleItemsProvider.notifier).clear();
      context.go('/sales/${sale.id}');
    } else {
      final state = ref.read(saleMutationControllerProvider);
      final failure = state.hasError ? state.error as Failure : Failure.unknown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final productsAsync = ref.watch(activeProductsForPickerProvider);
    final draftItems = ref.watch(draftSaleItemsProvider);
    final mutationState = ref.watch(saleMutationControllerProvider);

    final subtotalPreview = draftItems.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final discountPreview = double.tryParse(_overallDiscountController.text.trim()) ?? 0;
    final totalPreview = subtotalPreview - discountPreview;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create Sale', style: AppTextStyles.heading1),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  customersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('Could not load customers'),
                    data: (page) => DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      hint: const Text('Select a customer'),
                      items: page.items
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCustomerId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Add Item', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  productsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('Could not load products'),
                    data: (products) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            DropdownButtonFormField<Product>(
                              value: _selectedProduct,
                              decoration: const InputDecoration(labelText: 'Product'),
                              items: products
                                  .map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${Formatters.currency(p.defaultPrice)})')))
                                  .toList(),
                              onChanged: (p) {
                                setState(() {
                                  _selectedProduct = p;
                                  _priceController.text = p != null ? p.defaultPrice.toStringAsFixed(2) : '';
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final qtyField = TextField(
                                  controller: _qtyController,
                                  decoration: const InputDecoration(labelText: 'Quantity'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                );
                                final priceField = TextField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(labelText: 'Unit Price'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                );
                                final discountField = TextField(
                                  controller: _lineDiscountController,
                                  decoration: const InputDecoration(labelText: 'Line Discount'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                );

                                // 3 side-by-side fields leave ~110px each on
                                // a phone — too narrow for label + numeric
                                // input. Stack them below `compact` instead.
                                if (constraints.maxWidth < AppBreakpoints.compact) {
                                  return Column(
                                    children: [
                                      qtyField,
                                      const SizedBox(height: 10),
                                      priceField,
                                      const SizedBox(height: 10),
                                      discountField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: qtyField),
                                    const SizedBox(width: 10),
                                    Expanded(child: priceField),
                                    const SizedBox(width: 10),
                                    Expanded(child: discountField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add to Sale'),
                                onPressed: _addItem,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (draftItems.isNotEmpty) ...[
                    Text('Items (${draftItems.length})', style: AppTextStyles.heading3),
                    const SizedBox(height: 8),
                    ...draftItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(item.productName),
                          subtitle: Text('${item.quantity} × ${Formatters.currency(item.unitPrice)}'
                              '${item.lineDiscount > 0 ? ' − ${Formatters.currency(item.lineDiscount)}' : ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(Formatters.currency(item.lineTotal), style: AppTextStyles.body),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => ref.read(draftSaleItemsProvider.notifier).removeAt(i),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _overallDiscountController,
                      decoration: const InputDecoration(labelText: 'Overall Discount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: context.subtleSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _totalRow('Subtotal', subtotalPreview),
                            _totalRow('Discount', -discountPreview),
                            const Divider(),
                            _totalRow('Total', totalPreview, bold: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Create Sale & Generate Invoice',
            isLoading: mutationState.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = bold ? AppTextStyles.heading3 : AppTextStyles.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(Formatters.currency(value), style: style)],
      ),
    );
  }
}
