import 'package:lifeos_core/lifeos_core.dart';

import 'model.dart';

/// Erledigte Tage (`yyyy-mm-dd`) je Habit.
Map<String, Set<String>> doneDaysByHabit(Iterable<HabitCheck> checks) {
  final result = <String, Set<String>>{};
  for (final check in checks) {
    if (!check.done) continue;
    result.putIfAbsent(check.habitId, () => <String>{}).add(isoDate(check.date));
  }
  return result;
}

/// Wie viele fällige Tage in Folge das Habit erledigt wurde. Tage, an denen
/// es nicht dran ist, unterbrechen die Serie nicht. Ist es heute dran, aber
/// noch offen, zählt die Serie bis gestern.
int habitStreak(Habit habit, Set<String> doneDays, DateTime today) {
  var day = dateOnly(today);
  if (habit.isDueOn(day) && !doneDays.contains(isoDate(day))) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  for (var guard = 0; guard < 3660; guard++) {
    if (!habit.isDueOn(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
      continue;
    }
    if (!doneDays.contains(isoDate(day))) break;
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// Anteil erledigter fälliger Tage in den letzten [days] Tagen bis heute.
/// Heute zählt nur, wenn es schon erledigt ist.
double completionRate(Habit habit, Set<String> doneDays, DateTime today, {int days = 30}) {
  final end = dateOnly(today);
  var due = 0;
  var done = 0;
  for (var offset = 0; offset < days; offset++) {
    final day = DateTime(end.year, end.month, end.day - offset);
    if (!habit.isDueOn(day)) continue;
    final isDone = doneDays.contains(isoDate(day));
    if (offset == 0 && !isDone) continue;
    due++;
    if (isDone) done++;
  }
  return due == 0 ? 0 : done / due;
}
