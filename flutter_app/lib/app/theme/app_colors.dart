import 'package:flutter/material.dart';

/// Centralized color palette — "Ledger Clarity" direction: a light,
/// paperwork-clean canvas with brand accents pulled from the SK logo
/// (navy/blue/teal), used sparingly for emphasis — primary actions, active
/// navigation, icon accents and financial/success states. Never inline hex
/// colors in feature widgets — reference these instead, so a rebrand only
/// touches this one file.
///
/// Ships both a light palette (default) and a dark palette. Brand colors
/// (primary/accent/success/warning/error) are shared across both — only
/// backgrounds/surfaces/text/divider differ, so switching theme never
/// changes what "the brand" looks like, only the canvas it sits on.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF173B63); // SK logo navy
  static const Color primaryDark = Color(0xFF102944);
  static const Color accent = Color(0xFF2563A8); // SK logo blue — sparing emphasis only

  static const Color background = Color(0xFFF6F4EF); // warm canvas, not cold grey
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE7E2D8);

  static const Color success = Color(0xFF16A085); // SK logo teal — financial/success states
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFC0392B);
  static const Color info = Color(0xFF2563A8); // SK logo blue

  // Status badge colors (payment status, cheque status, task status, etc.)
  static const Color statusPaid = success;
  static const Color statusPartial = warning;
  static const Color statusUnpaid = error;
  static const Color statusPending = warning;
  static const Color statusCancelled = Color(0xFF8B8F98);

  // Dark theme surface/text tokens — brand colors above are reused as-is.
  static const Color darkBackground = Color(0xFF10151C);
  static const Color darkSurface = Color(0xFF1A222D);
  static const Color darkTextPrimary = Color(0xFFEAEDF1);
  static const Color darkTextSecondary = Color(0xFF9AA6B2);
  static const Color darkDivider = Color(0xFF2B3542);
}
