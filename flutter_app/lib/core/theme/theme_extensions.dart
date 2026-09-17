import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Small helper for the handful of "highlighted summary" cards (e.g. a
/// totals row) that want a subtly different background from a plain Card —
/// centralized here rather than repeating a brightness check at each call
/// site, so all of them stay in sync with the palette in both themes.
extension SubtleSurfaceColor on BuildContext {
  Color get subtleSurface =>
      Theme.of(this).brightness == Brightness.dark ? AppColorsDark.surfaceVariant : AppColors.background;
}
