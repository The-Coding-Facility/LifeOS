import 'package:lifeos_core/lifeos_core.dart';

import 'model.dart';

/// Summe aller Tracker-Einträge an [day].
DayIntake intakeOn(Iterable<NutritionLog> logs, DateTime day) {
  var kcal = 0.0;
  var protein = 0.0;
  var fat = 0.0;
  var water = 0.0;
  final key = isoDate(day);
  for (final log in logs) {
    if (isoDate(log.date) != key) continue;
    kcal += log.kcal;
    protein += log.protein;
    fat += log.fat;
    water += log.waterMl;
  }
  return DayIntake(kcal: kcal, protein: protein, fat: fat, waterMl: water);
}

/// Ein Punkt einer Zeitreihe.
typedef SeriesPoint = ({DateTime date, double value});

/// Werte einer Messung ab [from], ältester zuerst. Bei [Measure.sleepHours]
/// ergänzt [sleepFallback] fehlende Tage (z. B. aus dem Daily Report).
List<SeriesPoint> measureSeries(
  Iterable<BodyEntry> entries,
  Measure measure, {
  DateTime? from,
  Map<String, double> sleepFallback = const {},
}) {
  final byDay = <String, SeriesPoint>{};
  for (final entry in entries) {
    if (from != null && entry.date.isBefore(dateOnly(from))) continue;
    final value = entry.values[measure];
    if (value != null) byDay[isoDate(entry.date)] = (date: entry.date, value: value);
  }
  if (measure == Measure.sleepHours) {
    for (final MapEntry(key: day, value: hours) in sleepFallback.entries) {
      final date = parseIsoDate(day);
      if (from != null && date.isBefore(dateOnly(from))) continue;
      byDay.putIfAbsent(day, () => (date: date, value: hours));
    }
  }
  return byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

/// Schlafdauer in Stunden: eingetragen oder, falls leer, aus dem Daily Report.
double? effectiveSleep(BodyEntry? entry, Duration? reportSleep) {
  final own = entry?.values[Measure.sleepHours];
  if (own != null) return own;
  if (reportSleep == null) return null;
  return reportSleep.inMinutes / 60;
}

/// Bester Wert von [metric] bei [exerciseId] je Training, ältestes zuerst.
List<SeriesPoint> exerciseSeries(Iterable<WorkoutSession> sessions, String exerciseId, ResultMetric metric) {
  final points = <SeriesPoint>[];
  for (final session in sessions) {
    double? best;
    for (final result in session.results) {
      if (result.exerciseId != exerciseId) continue;
      final value = result.values[metric];
      if (value != null && (best == null || value > best)) best = value;
    }
    if (best != null) points.add((date: session.startedAt, value: best));
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}
