/// Form field validators returning a Material-style error string (or null when
/// valid) so they slot straight into `TextFormField.validator`.
class Validators {
  const Validators._();

  static String? required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  /// Indian mobile: exactly 10 digits, leading 6–9.
  static String? phone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return 'Mobile number is required';
    if (s.length != 10) return 'Enter a 10-digit mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(s)) return 'Invalid mobile number';
    return null;
  }

  /// Aadhaar: 12 digits.
  static String? aadhaar(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return null; // optional at entry; required at verification
    if (s.length != 12) return 'Aadhaar must be 12 digits';
    return null;
  }

  /// PAN: ABCDE1234F.
  static String? pan(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    if (s.isEmpty) return null;
    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(s)) return 'Invalid PAN format';
    return null;
  }

  static String? positiveAmount(String? v, {String field = 'Amount'}) {
    final s = (v ?? '').replaceAll(RegExp(r'[,\s₹]'), '');
    if (s.isEmpty) return '$field is required';
    final n = num.tryParse(s);
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return '$field must be greater than zero';
    return null;
  }

  static String? minLength(String? v, int n, {String field = 'This field'}) {
    if ((v ?? '').trim().length < n) return '$field must be at least $n characters';
    return null;
  }
}
