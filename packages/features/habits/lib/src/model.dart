import 'package:lifeos_design_system/lifeos_design_system.dart';

/// Eine Gewohnheit.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.weekdays = const {},
    this.archived = false,
  });

  final String id;
  final String name;
  final int colorIndex;

  /// 1 = Montag … 7 = Sonntag. Leer = jeden Tag.
  final Set<int> weekdays;
  final bool archived;

  bool get daily => weekdays.isEmpty;

  /// Ist das Habit an [day] dran?
  bool isDueOn(DateTime day) => weekdays.isEmpty || weekdays.contains(day.weekday);

  /// „Jeden Tag“ oder z. B. „Mo, Mi, Fr“.
  String get scheduleText => weekdays.isEmpty
      ? 'Jeden Tag'
      : (weekdays.toList()..sort()).map((day) => germanWeekdaysShort[day - 1]).join(', ');
}

/// Ein Haken: Habit an einem Tag erledigt.
class HabitCheck {
  const HabitCheck({required this.habitId, required this.date, required this.done});

  final String habitId;

  /// Tag (lokale Mitternacht).
  final DateTime date;
  final bool done;
}
