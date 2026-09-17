import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dedicated, reusable logo slot. Renders the real SK logo from
/// `assets/logo.png` (declared in pubspec.yaml). Every place that shows the
/// brand mark (nav rail, drawer header, login screen, settings) goes
/// through this one widget, so any future logo change is a single-file
/// swap. Falls back to a lightweight "SK" monogram if the asset can't be
/// loaded for any reason (e.g. it's missing at build time) so the layout
/// never breaks.
class CompanyLogoMark extends StatelessWidget {
  const CompanyLogoMark({super.key, this.size = 40, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.surfaceVariant : AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Text(
            'SK',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: isDark ? AppColorsDark.accent : Colors.white,
            ),
          ),
        ),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        const Text(
          'Sai Krishna\nEnterprises',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
        ),
      ],
    );
  }
}
