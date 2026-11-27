import 'report_math.dart';

/// Ein Daily Report. Es gibt höchstens einen je Tag.
class DailyReport {
  const DailyReport({
    required this.date,
    this.successes = '',
    this.learned = '',
    this.calendarDone = false,
    this.kcalGoalMet = false,
    this.waterGoalMet = false,
    this.sleptAt,
    this.wokeAt,
    this.activities = '',
  });

  /// Tag des Berichts (lokale Mitternacht).
  final DateTime date;
  final String successes;
  final String learned;
  final bool calendarDone;
  final bool kcalGoalMet;
  final bool waterGoalMet;

  /// Schlafen gegangen und aufgestanden, Minuten seit Mitternacht.
  final int? sleptAt;
  final int? wokeAt;
  final String activities;

  Duration? get sleep => sleepDuration(sleptAt, wokeAt);
}
