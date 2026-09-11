import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
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
    this.iconColor = AppColors.primary,
    this.subtitle,
    this.isHero = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: iconColor),
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
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, size: 18, color: iconColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
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
    );
  }
}
