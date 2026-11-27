import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';
import 'report_math.dart';

/// Lesen und Schreiben von Daily Reports. Die ID entsteht aus dem Datum.
///
/// Feldgruppen: `date`, `successes`, `learned`, `checks` (Kalender, kcal,
/// Wasser), `sleep` (Schlafen, Aufstehen), `activities`.
class DailyReportRepository {
  DailyReportRepository(this._db, this._recorder);

  static const String entity = 'daily_reports';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// ID des Berichts für [date]; auf jedem Gerät gleich.
  static String idFor(DateTime date) => Ids.deterministic('daily_report', isoDate(date));

  static const Map<String, List<String>> _groups = {
    'date': ['date'],
    'successes': ['successes'],
    'learned': ['learned'],
    'checks': ['calendar_done', 'kcal_goal_met', 'water_goal_met'],
    'sleep': ['slept_at', 'woke_at'],
    'activities': ['activities'],
  };

  /// Alle Berichte, neueste zuerst.
  Stream<List<DailyReport>> watchAll() {
    final query = _db.select(_db.dailyReports)
      ..where((report) => report.deletedHlc.isNull())
      ..orderBy([(report) => OrderingTerm.desc(report.date)]);
    return query.watch().map((rows) => [for (final row in rows) _toReport(row)]);
  }

  Future<DailyReport?> find(DateTime date) async {
    final row = await (_db.select(_db.dailyReports)
          ..where((report) => report.id.equals(idFor(date)) & report.deletedHlc.isNull()))
        .getSingleOrNull();
    return row == null ? null : _toReport(row);
  }

  /// Speichert den Bericht seines Tages. Gibt es ihn schon, werden nur die
  /// geänderten Feldgruppen protokolliert.
  Future<void> save(DailyReport report) {
    return _db.transaction(() async {
      final id = idFor(report.date);
      final wanted = _columnsOf(report);
      final row = await (_db.select(_db.dailyReports)..where((r) => r.id.equals(id))).getSingleOrNull();

      final Map<String, Map<String, Object?>> groups;
      if (row == null || row.deletedHlc != null) {
        groups = {
          for (final MapEntry(key: group, value: columns) in _groups.entries)
            group: {for (final column in columns) column: wanted[column]},
          if (row != null) deletedFieldGroup: {'deleted': false},
        };
      } else {
        final existing = _columnsOfRow(row);
        groups = {
          for (final MapEntry(key: group, value: columns) in _groups.entries)
            if (columns.any((column) => wanted[column] != existing[column]))
              group: {for (final column in columns) column: wanted[column]},
        };
        if (groups.isEmpty) return;
      }

      final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
      final companion = DailyReportsCompanion(
        date: Value(wanted['date']! as String),
        successes: Value(wanted['successes']! as String),
        learned: Value(wanted['learned']! as String),
        calendarDone: Value(wanted['calendar_done']! as bool),
        kcalGoalMet: Value(wanted['kcal_goal_met']! as bool),
        waterGoalMet: Value(wanted['water_goal_met']! as bool),
        sleptAt: Value(wanted['slept_at'] as String?),
        wokeAt: Value(wanted['woke_at'] as String?),
        activities: Value(wanted['activities']! as String),
        deletedHlc: const Value(null),
        updatedHlc: Value(hlc.pack()),
        updatedBy: Value(_recorder.deviceId),
      );
      if (row == null) {
        await _db.into(_db.dailyReports).insert(
              companion.copyWith(
                id: Value(id),
                createdAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
                createdBy: Value(_recorder.deviceId),
              ),
            );
      } else {
        await (_db.update(_db.dailyReports)..where((r) => r.id.equals(id))).write(companion);
      }
    });
  }

  /// Löscht den Bericht von [date] als Tombstone.
  Future<void> delete(DateTime date) {
    return _db.transaction(() async {
      final id = idFor(date);
      final row = await (_db.select(_db.dailyReports)
            ..where((r) => r.id.equals(id) & r.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await (_db.update(_db.dailyReports)..where((r) => r.id.equals(id))).write(
        DailyReportsCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  static Map<String, Object?> _columnsOf(DailyReport report) => {
        'date': isoDate(report.date),
        'successes': report.successes.trim(),
        'learned': report.learned.trim(),
        'calendar_done': report.calendarDone,
        'kcal_goal_met': report.kcalGoalMet,
        'water_goal_met': report.waterGoalMet,
        'slept_at': report.sleptAt == null ? null : formatClock(report.sleptAt!),
        'woke_at': report.wokeAt == null ? null : formatClock(report.wokeAt!),
        'activities': report.activities.trim(),
      };

  static Map<String, Object?> _columnsOfRow(DailyReportRow row) => {
        'date': row.date,
        'successes': row.successes,
        'learned': row.learned,
        'calendar_done': row.calendarDone,
        'kcal_goal_met': row.kcalGoalMet,
        'water_goal_met': row.waterGoalMet,
        'slept_at': row.sleptAt,
        'woke_at': row.wokeAt,
        'activities': row.activities,
      };

  static DailyReport _toReport(DailyReportRow row) {
    DateTime date;
    try {
      date = parseIsoDate(row.date);
    } on FormatException {
      date = DateTime(1970);
    }
    return DailyReport(
      date: date,
      successes: row.successes,
      learned: row.learned,
      calendarDone: row.calendarDone,
      kcalGoalMet: row.kcalGoalMet,
      waterGoalMet: row.waterGoalMet,
      sleptAt: parseClock(row.sleptAt),
      wokeAt: parseClock(row.wokeAt),
      activities: row.activities,
    );
  }
}
