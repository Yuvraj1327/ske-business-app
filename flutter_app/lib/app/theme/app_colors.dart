import 'package:flutter/material.dart';

/// Centralized color palette — brand direction built around the SK logo's
/// three colors (Navy #173B63, Blue #2563A8, Teal #16A085), used
/// selectively rather than everywhere: backgrounds and cards stay
/// white/light-neutral, and the brand colors are reserved for primary
/// buttons, active navigation, important icons, selected states, and
/// financial highlights. Never inline hex colors in feature widgets —
/// reference these instead, so a future rebrand only touches this file.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF173B63); // Navy — buttons, active nav, headings emphasis
  static const Color primaryDark = Color(0xFF0F2645);
  static const Color accent = Color(0xFF2563A8); // Blue — secondary actions, links, selected chips
  static const Color highlight = Color(0xFF16A085); // Teal — financial highlights (paid/positive figures)

  static const Color background = Color(0xFFF6F7F9); // cool light-neutral canvas
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF667085);
  static const Color divider = Color(0xFFE4E7EC);

  static const Color success = highlight; // reuses brand teal for "paid"/positive
  static const Color warning = Color(0xFFC08A1E);
  static const Color error = Color(0xFFD64545);
  static const Color info = accent;

  // Status badge colors (payment status, cheque status, task status, etc.)
  static const Color statusPaid = success;
  static const Color statusPartial = warning;
  static const Color statusUnpaid = error;
  static const Color statusPending = warning;
  static const Color statusCancelled = Color(0xFF8B8F98);
}

/// Dark-mode surface/background values, consumed only by `AppTheme.dark`'s
/// ColorScheme (see app_theme.dart) — kept separate from [AppColors]
/// because dark mode needs different structural values (backgrounds/
/// surfaces invert), not different semantic/status values (those stay
/// legible as-is on both, since they're always shown inside a tinted,
/// low-opacity chip rather than as a solid background).
class AppColorsDark {
  AppColorsDark._();

  static const Color background = Color(0xFF0E1420);
  static const Color surface = Color(0xFF161D2B);
  static const Color surfaceVariant = Color(0xFF1E2637);
  static const Color primary = Color(0xFF6FA8DC); // lightened Blue — legible on dark
  static const Color accent = Color(0xFF35C29B); // lightened Teal for dark contrast
  static const Color textPrimary = Color(0xFFEDEFF3);
  static const Color textSecondary = Color(0xFF98A2B3);
  static const Color divider = Color(0xFF29303F);
}
