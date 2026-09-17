import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';

/// A compact quick-action tile for the dashboard's "frequently used
/// actions" row (New Sale, Record Payment, Add Customer, ...). Deliberately
/// small and icon-led so a row of 2-4 fits without wrapping awkwardly on
/// mobile. Built on top of `Card` (rather than a hand-rolled Container) so
/// its border/background automatically pick up the correct light/dark
/// theme colors instead of hardcoding one.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
