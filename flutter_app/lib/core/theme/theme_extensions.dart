import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Small helper for the handful of "highlighted summary" cards (e.g. a
/// totals row) that want a subtly different background from a plain Card —
/// centralized here rather than repeating the color choice at each call
/// site, so all of them stay in sync with the palette.
extension SubtleSurfaceColor on BuildContext {
  Color get subtleSurface => AppColors.background;
}
