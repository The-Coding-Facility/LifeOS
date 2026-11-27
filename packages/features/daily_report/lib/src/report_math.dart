import 'package:lifeos_core/lifeos_core.dart';

/// `23:30` → 1410 Minuten seit Mitternacht; ungültig → `null`.
int? parseClock(String? text) {
  if (text == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// 1410 → `23:30`.
String formatClock(int minutes) {
  final normalized = minutes % 1440;
  return '${(normalized ~/ 60).toString().padLeft(2, '0')}:${(normalized % 60).toString().padLeft(2, '0')}';
}

/// Schlafdauer aus Schlafengehen und Aufstehen (Minuten seit Mitternacht).
/// Liegt Aufstehen früher als Schlafengehen, geht der Schlaf über
/// Mitternacht: 23:30 → 07:00 sind 7:30 h.
Duration? sleepDuration(int? sleptAt, int? wokeAt) {
  if (sleptAt == null || wokeAt == null) return null;
  var minutes = wokeAt - sleptAt;
  if (minutes < 0) minutes += 1440;
  return Duration(minutes: minutes);
}

/// `7:30 h`
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')} h';
}

/// Tage in Folge mit Bericht bis heute. Fehlt der heutige Bericht noch,
/// zählt die Serie bis gestern (der Tag ist ja noch nicht vorbei).
int reportStreak(Iterable<DateTime> reportDates, DateTime today) {
  final keys = {for (final date in reportDates) isoDate(date)};
  var day = dateOnly(today);
  if (!keys.contains(isoDate(day))) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while (keys.contains(isoDate(day)) && streak < 100000) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}
