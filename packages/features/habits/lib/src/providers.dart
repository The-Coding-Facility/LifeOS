import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'habit_repository.dart';
import 'model.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => throw UnimplementedError('habitRepositoryProvider muss in main() überschrieben werden.'),
);

/// Aktive Habits.
final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchHabits(),
);

/// Erledigte Haken der letzten gut 13 Monate (für Serien und Statistik).
final habitChecksProvider = StreamProvider<List<HabitCheck>>((ref) {
  final now = DateTime.now();
  return ref.watch(habitRepositoryProvider).watchChecks(from: DateTime(now.year - 1, now.month - 1, now.day));
});
