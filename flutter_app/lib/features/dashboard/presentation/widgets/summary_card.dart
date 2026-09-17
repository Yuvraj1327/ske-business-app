import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';

/// A single dashboard metric card. Uses a left accent bar keyed to the
/// metric's category instead of an identical shadow-card-kit look for every
/// tile, so the grid reads as differentiated categories rather than
/// interchangeable boxes. [isHero] renders a larger figure for the one
/// number on the page that deserves the most visual weight (e.g.
/// Outstanding, the most actionable figure for a trade business).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.isHero = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  /// When omitted, resolves to the current theme's primary color (correct
  /// for both light and dark) rather than a hardcoded light-mode constant.
  final Color? iconColor;
  final String? subtitle;
  final bool isHero;
  /// Optional — when set, the whole card becomes tappable (e.g. "Payments
  /// Received" opens a Cash/Online/Credit breakdown). Cards without a
  /// handler render and behave exactly as before.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: resolvedIconColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: resolvedIconColor.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(icon, size: 17, color: resolvedIconColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
                          if (onTap != null) Icon(Icons.chevron_right, size: 16, color: Theme.of(context).hintColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        value,
                        style: isHero ? AppTextStyles.amountLarge : AppTextStyles.heading1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
