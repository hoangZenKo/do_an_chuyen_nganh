// Formatting helpers shared across screens so numbers read consistently with
// the dashboard (e.g. `3.500.000 đ`).

/// Formats an integer amount with `.` thousands separators, e.g.
/// `3500000` -> `3.500.000`.
String formatThousands(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer';
}

/// Formats a VND amount with a trailing đ symbol, e.g. `3.500.000 đ`.
String formatCurrencyVnd(int amount) => '${formatThousands(amount)} đ';

/// Formats an optional area, e.g. `25.0` -> `25 m²`, `25.5` -> `25.5 m²`.
String formatArea(double? areaSqm) {
  if (areaSqm == null) return '—';
  final rounded = areaSqm == areaSqm.roundToDouble()
      ? areaSqm.toStringAsFixed(0)
      : areaSqm.toStringAsFixed(1);
  return '$rounded m²';
}

/// Formats a date as `dd/MM/yyyy`, or `—` when null.
String formatDate(DateTime? date) {
  if (date == null) return '—';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

/// Formats a month as `MM/yyyy`, or `—` when null.
String formatMonth(DateTime? date) {
  if (date == null) return '—';
  final m = date.month.toString().padLeft(2, '0');
  return '$m/${date.year}';
}
