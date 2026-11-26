/// Kalenderdaten ohne Uhrzeit werden als `yyyy-mm-dd` gespeichert.
library;

/// `DateTime(2026, 3, 5, 23, 59)` → `2026-03-05`. Nutzt Jahr, Monat und Tag
/// so, wie sie im übergebenen Wert stehen (lokal oder UTC).
String isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

final _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `2026-03-05` → lokale Mitternacht dieses Tages.
DateTime parseIsoDate(String text) {
  final match = _isoDatePattern.firstMatch(text.trim());
  if (match == null) {
    throw FormatException('Kein Datum im Format yyyy-mm-dd', text);
  }
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Lokale Mitternacht des Tages von [date].
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
