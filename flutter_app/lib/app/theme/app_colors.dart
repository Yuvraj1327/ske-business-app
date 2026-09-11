import 'package:flutter/material.dart';

/// Centralized color palette — "Ledger Clarity" direction: a trustworthy
/// deep-navy base with a warm brass accent (evokes stamped paperwork and
/// well-kept ledgers, distinct from generic SaaS blue/teal), used sparingly
/// for emphasis. Never inline hex colors in feature widgets — reference
/// these instead, so a rebrand only touches this one file.
///
/// Light theme only — the app does not offer dark mode / theme switching.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF152238); // ink navy
  static const Color primaryDark = Color(0xFF0D1626);
  static const Color accent = Color(0xFFB08D46); // warm brass — sparing emphasis only

  static const Color background = Color(0xFFF6F4EF); // warm canvas, not cold grey
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE7E2D8);

  static const Color success = Color(0xFF2F7D5A);
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFC0392B);
  static const Color info = Color(0xFF3B6EA8);

  // Status badge colors (payment status, cheque status, task status, etc.)
  static const Color statusPaid = success;
  static const Color statusPartial = warning;
  static const Color statusUnpaid = error;
  static const Color statusPending = warning;
  static const Color statusCancelled = Color(0xFF8B8F98);
}
