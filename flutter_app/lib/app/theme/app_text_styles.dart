import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for the "Ledger Clarity" direction: bold weight is reserved
/// for headings and monetary figures only — never for body text or captions
/// — so a bold label actually signals importance instead of everything
/// looking equally loud. Large figures get a touch of negative letter
/// spacing, which reads closer to typeset ledger numerals than default
/// loose-tracked system type.
///
/// Primary-emphasis styles (heading1/2/3, body, amount, amountLarge)
/// intentionally do NOT set `color` here — they inherit the ambient
/// `DefaultTextStyle` from `Theme.of(context).textTheme`
/// (`AppTheme.light`'s `textTheme.apply(...)`), so a single palette change
/// in app_theme.dart cascades correctly everywhere instead of needing
/// per-screen edits. `bodySecondary`/`caption` keep an explicit muted-gray
/// color since they're deliberately dimmer than primary text.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// For the large hero figure on a KPI card (e.g. the Outstanding total).
  static const TextStyle amountLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
}
