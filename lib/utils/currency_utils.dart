import 'package:intl/intl.dart';

/// Cached VND currency formatter for consistent formatting across the app.
/// Uses Vietnamese locale with 0 decimal digits (VND doesn't use cents).
final NumberFormat _vndFormatter =
    NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0);

/// Formats a numeric amount as Vietnamese Dong (VND) currency.
///
/// Uses a cached NumberFormat instance to avoid unnecessary allocations.
/// Example: formatCurrency(1234567) returns "VND1,234,567"
String formatCurrency(num amount) => _vndFormatter.format(amount);
