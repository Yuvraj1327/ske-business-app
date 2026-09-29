import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

const _denominations = [500, 100, 50, 20];

/// Compact ₹500 / ₹100 / ₹50 / ₹20 note counter. Returns the total cash
/// (sum of denomination x count), or null if cancelled.
Future<double?> showCashNoteBreakdownDialog(BuildContext context) {
  return showDialog<double>(context: context, builder: (_) => const _CashNoteBreakdownDialog());
}

class _CashNoteBreakdownDialog extends StatefulWidget {
  const _CashNoteBreakdownDialog();

  @override
  State<_CashNoteBreakdownDialog> createState() => _CashNoteBreakdownDialogState();
}

class _CashNoteBreakdownDialogState extends State<_CashNoteBreakdownDialog> {
  final Map<int, TextEditingController> _controllers = {
    for (final d in _denominations) d: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total =>
      _denominations.fold(0, (sum, d) => sum + d * (int.tryParse(_controllers[d]!.text.trim()) ?? 0));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cash by Notes'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in _denominations)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text('₹$d ×', style: AppTextStyles.body)),
                    Expanded(
                      child: TextField(
                        controller: _controllers[d],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, hintText: '0'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Text('Total Cash', style: AppTextStyles.body),
                const Spacer(),
                Text(Formatters.currency(_total), style: AppTextStyles.amount),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_total), child: const Text('Apply')),
      ],
    );
  }
}
