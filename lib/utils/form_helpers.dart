/// Parses a number typed by the user. Accepts both "6.5" and "6,5"
/// (the decimal comma used on Turkish keyboards).
double? parseUserNumber(String text) {
  return double.tryParse(text.trim().replaceAll(',', '.'));
}

/// True if [value] has at most [digits] decimal places (for example 6.25
/// has 2). The backend rejects more than it allows.
bool hasAtMostDecimals(double value, int digits) {
  final scaled = value * _pow10(digits);
  return (scaled - scaled.round()).abs() < 1e-6;
}

double _pow10(int digits) {
  var result = 1.0;
  for (var i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}

/// 6.0 -> "6", 6.5 -> "6.5"
String formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }

  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "06/10/2026 14:05"
String formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');

  return '$day/$month/${value.year} ${formatClock(value)}';
}

/// "14:05"
String formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

/// "Today • 14:05", "Yesterday • 09:30" or "04/10 • 18:00"
String formatRelativeDay(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final difference = today.difference(day).inDays;

  final String label;

  if (difference == 0) {
    label = 'Today';
  } else if (difference == 1) {
    label = 'Yesterday';
  } else {
    label =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
  }

  return '$label • ${formatClock(value)}';
}
