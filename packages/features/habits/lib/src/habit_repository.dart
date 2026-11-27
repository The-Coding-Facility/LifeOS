import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Lesen und Schreiben von Habits und ihren Haken.
///
/// Habits: Feldgruppen `name`, `color`, `schedule`, `archived`.
/// Haken: eine Zeile je Habit und Tag, ID aus beiden; Feldgruppen `key`
/// (Habit, Datum) und `done`. Haken werden nie gelöscht, nur umgeschaltet.
class HabitRepository {
  HabitRepository(this._db, this._recorder);

  static const String habitsEntity = 'habits';
  static const String checksEntity = 'habit_checks';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// ID des Hakens von [habitId] an [date]; auf jedem Gerät gleich.
  static String checkId(String habitId, DateTime date) =>
      Ids.deterministic('habit_check', '$habitId|${isoDate(date)}');

  /// Aktive Habits in der Reihenfolge des Anlegens.
  Stream<List<Habit>> watchHabits() {
    final query = _db.select(_db.habits)
      ..where((habit) => habit.deletedHlc.isNull() & habit.archived.equals(false))
      ..orderBy([(habit) => OrderingTerm.asc(habit.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _toHabit(row)]);
  }

  /// Erledigte Haken ab [from].
  Stream<List<HabitCheck>> watchChecks({required DateTime from}) {
    final query = _db.select(_db.habitChecks)
      ..where(
        (check) =>
            check.deletedHlc.isNull() &
            check.done.equals(true) &
            check.date.isBiggerOrEqualValue(isoDate(from)),
      );
    return query.watch().map((rows) => [for (final row in rows) _toCheck(row)]);
  }

  Future<String> create(String name, {int colorIndex = 0, Set<int> weekdays = const {}}) {
    final cleanName = _requireName(name);
    return _db.transaction(() async {
      final id = Ids.newId();
      final encoded = _encodeDays(weekdays);
      final hlc = await _recorder.record(
        entity: habitsEntity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'name': {'name': cleanName},
          'color': {'color_index': colorIndex},
          'schedule': {'weekdays': encoded},
          'archived': {'archived': false},
        },
      );
      await _db.into(_db.habits).insert(
            HabitsCompanion.insert(
              id: id,
              name: cleanName,
              colorIndex: Value(colorIndex),
              weekdays: Value(encoded),
              createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
  }

  Future<void> update(String id, {String? name, int? colorIndex, Set<int>? weekdays}) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null) return;
      final groups = <String, Map<String, Object?>>{};
      final newName = name == null ? null : _requireName(name);
      if (newName != null && newName != row.name) groups['name'] = {'name': newName};
      if (colorIndex != null && colorIndex != row.colorIndex) groups['color'] = {'color_index': colorIndex};
      final encoded = weekdays == null ? null : _encodeDays(weekdays);
      if (encoded != null && encoded != row.weekdays) groups['schedule'] = {'weekdays': encoded};
      if (groups.isEmpty) return;
      final hlc = await _recorder.record(entity: habitsEntity, recordId: id, op: ChangeOp.upsert, groups: groups);
      await (_db.update(_db.habits)..where((habit) => habit.id.equals(id))).write(
        HabitsCompanion(
          name: groups.containsKey('name') ? Value(newName!) : const Value.absent(),
          colorIndex: groups.containsKey('color') ? Value(colorIndex!) : const Value.absent(),
          weekdays: groups.containsKey('schedule') ? Value(encoded!) : const Value.absent(),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Blendet ein Habit aus, ohne seine Haken zu verlieren.
  Future<void> archive(String id) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null || row.archived) return;
      final hlc = await _recorder.record(
        entity: habitsEntity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'archived': {'archived': true},
        },
      );
      await (_db.update(_db.habits)..where((habit) => habit.id.equals(id))).write(
        HabitsCompanion(
          archived: const Value(true),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Löscht ein Habit als Tombstone.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null) return;
      final hlc = await _recorder.record(
        entity: habitsEntity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await (_db.update(_db.habits)..where((habit) => habit.id.equals(id))).write(
        HabitsCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Hakt [habitId] an [date] ab oder nimmt den Haken zurück.
  Future<void> setDone(String habitId, DateTime date, bool done) {
    return _db.transaction(() async {
      final id = checkId(habitId, date);
      final row = await (_db.select(_db.habitChecks)..where((check) => check.id.equals(id))).getSingleOrNull();
      if (row != null && row.done == done) return;
      final hlc = await _recorder.record(
        entity: checksEntity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          if (row == null) 'key': {'habit_id': habitId, 'date': isoDate(date)},
          'done': {'done': done},
        },
      );
      if (row == null) {
        await _db.into(_db.habitChecks).insert(
              HabitChecksCompanion.insert(
                id: id,
                habitId: habitId,
                date: isoDate(date),
                done: Value(done),
                createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
                createdBy: _recorder.deviceId,
                updatedHlc: hlc.pack(),
                updatedBy: _recorder.deviceId,
              ),
            );
      } else {
        await (_db.update(_db.habitChecks)..where((check) => check.id.equals(id))).write(
          HabitChecksCompanion(
            done: Value(done),
            updatedHlc: Value(hlc.pack()),
            updatedBy: Value(_recorder.deviceId),
          ),
        );
      }
    });
  }

  Future<HabitRow?> _findActive(String id) =>
      (_db.select(_db.habits)..where((habit) => habit.id.equals(id) & habit.deletedHlc.isNull())).getSingleOrNull();

  static String _encodeDays(Set<int> weekdays) =>
      jsonEncode([for (final day in weekdays) if (day >= 1 && day <= 7) day]..sort());

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Ein Habit braucht einen Namen.');
    return trimmed;
  }

  static Habit _toHabit(HabitRow row) {
    var weekdays = <int>{};
    try {
      final decoded = jsonDecode(row.weekdays);
      if (decoded is List) weekdays = {for (final day in decoded) if (day is int) day};
    } on FormatException {
      weekdays = {};
    }
    return Habit(
      id: row.id,
      name: row.name,
      colorIndex: row.colorIndex,
      weekdays: weekdays,
      archived: row.archived,
    );
  }

  static HabitCheck _toCheck(HabitCheckRow row) {
    DateTime date;
    try {
      date = parseIsoDate(row.date);
    } on FormatException {
      date = DateTime(1970);
    }
    return HabitCheck(habitId: row.habitId, date: date, done: row.done);
  }
}
