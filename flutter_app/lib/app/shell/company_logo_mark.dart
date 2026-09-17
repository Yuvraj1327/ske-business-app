import 'package:flutter/material.dart';

/// Dedicated, reusable logo slot — every place that shows the brand mark
/// (nav rail, drawer header, login screen) goes through this one widget,
/// so a rebrand is a single-file change.
class CompanyLogoMark extends StatelessWidget {
  const CompanyLogoMark({super.key, this.size = 40, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text(
          'Sai Krishna\nEnterprises',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ],
    );
  }
}
