import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dedicated, reusable logo slot. Currently renders a monogram placeholder
/// so the layout looks finished today — swap in the real logo later by
/// replacing the `child` here with `Image.asset('assets/logo.png')` (or
/// similar); every place that shows the brand mark (nav rail, drawer header,
/// login screen) already goes through this one widget, so that's a
/// single-file change when the logo is ready.
class CompanyLogoMark extends StatelessWidget {
  const CompanyLogoMark({super.key, this.size = 40, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        'SK',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: Colors.white,
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
