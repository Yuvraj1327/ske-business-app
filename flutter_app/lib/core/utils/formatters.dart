import 'package:intl/intl.dart';

/// Currency/date formatting helpers. Centralized so "₹" and date patterns
/// aren't scattered/duplicated across every screen.
class Formatters {
  Formatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String currency(num amount) => _currencyFormat.format(amount);

  static String date(DateTime date) => _dateFormat.format(date);

  static String dateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Formats a role's raw DB name (e.g. `delivery_agent`, `admin`,
  /// `salesman`) into a human-readable label (`Delivery Agent`, `Admin`,
  /// `Salesman`) for display. Roles are fully data-driven — this only
  /// affects presentation, never the underlying value sent to the API.
  static String roleLabel(String rawRoleName) {
    if (rawRoleName.isEmpty) return rawRoleName;
    return rawRoleName
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
