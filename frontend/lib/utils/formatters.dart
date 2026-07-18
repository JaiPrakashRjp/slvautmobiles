import 'package:intl/intl.dart';

/// Indian-locale formatting helpers. Currency uses lakh grouping (₹1,80,000),
/// dates render as `28 Jun 2026`, phones as `+91 98765 43210`, and vehicle
/// registrations normalise to `KA-01-AB-1234`.
class Formatters {
  const Formatters._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrCompactDigits = NumberFormat.decimalPattern('en_IN');

  static final DateFormat _date = DateFormat('dd MMM yyyy', 'en_IN');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, h:mm a', 'en_IN');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'en_IN');

  /// `₹1,80,000`
  static String currency(num value) => _inr.format(value);

  /// `1,80,000` (no symbol) — for inputs/tables where the ₹ is shown separately.
  static String number(num value) => _inrCompactDigits.format(value);

  /// `28 Jun 2026`
  static String date(DateTime d) => _date.format(d);

  /// `July 2026`
  static String monthYear(DateTime d) => _monthYear.format(d);

  /// `28 Jun 2026, 4:30 PM`
  static String dateTime(DateTime d) => _dateTime.format(d);

  /// Lightweight relative time ("just now", "3 days ago", else absolute date).
  static String relative(DateTime d, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return date(d);
  }

  /// Accepts 10 digits or +91-prefixed, renders `+91 98765 43210`.
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final ten = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (ten.length != 10) return raw;
    return '+91 ${ten.substring(0, 5)} ${ten.substring(5)}';
  }

  /// Normalises free-form registration text to `KA-01-AB-1234` where possible.
  static String registration(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final m = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{1,3})(\d{1,4})$').firstMatch(s);
    if (m == null) return raw.toUpperCase();
    return '${m.group(1)}-${m.group(2)}-${m.group(3)}-${m.group(4)}';
  }

  /// Days remaining until [due] (negative if overdue), counted by calendar day.
  static int daysUntil(DateTime due, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = DateTime(due.year, due.month, due.day);
    return b.difference(a).inDays;
  }
}
