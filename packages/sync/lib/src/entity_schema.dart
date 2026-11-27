import 'package:drift/drift.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

/// Beschreibt, wie empfangene Änderungen in eine Fachtabelle geschrieben
/// werden. Nur hier genannte Spalten werden je geschrieben, damit ein
/// fremdes Gerät keine beliebigen Spalten setzen kann.
class EntitySchema {
  const EntitySchema({
    required this.table,
    required this.tableOf,
    required this.groups,
    this.insertDefaults = const {},
  });

  /// SQL-Name der Tabelle, gleich dem `entity` im Änderungsprotokoll.
  final String table;

  /// Die Drift-Tabelle, damit Ansichten nach dem Sync aktualisiert werden.
  final TableInfo<Table, Object?> Function(LifeosDatabase db) tableOf;

  /// Feldgruppe → SQL-Spalten.
  final Map<String, List<String>> groups;

  /// Pflichtwerte für eine neu angelegte Zeile, bevor die Gruppen
  /// geschrieben werden.
  final Map<String, Object?> insertDefaults;
}

/// Alle Fachtabellen, die synchronisiert werden.
final Map<String, EntitySchema> defaultEntitySchemas = {
  'tasks': EntitySchema(
    table: 'tasks',
    tableOf: (db) => db.tasks,
    insertDefaults: const {'title': ''},
    groups: const {
      'title': ['title'],
      'details': ['details'],
      'done': ['done', 'done_at'],
      'due': ['due_date'],
      'project': ['project_id'],
    },
  ),
  'notes': EntitySchema(
    table: 'notes',
    tableOf: (db) => db.notes,
    groups: const {
      'title': ['title'],
      'body': ['body'],
      'project': ['project_id'],
      'pinned': ['pinned'],
    },
  ),
  'tags': EntitySchema(
    table: 'tags',
    tableOf: (db) => db.tags,
    insertDefaults: const {'scope': '', 'name': ''},
    groups: const {
      'scope': ['scope'],
      'name': ['name'],
      'color': ['color_index'],
      'limit': ['monthly_limit_cents'],
    },
  ),
  'calendar_events': EntitySchema(
    table: 'calendar_events',
    tableOf: (db) => db.calendarEvents,
    insertDefaults: const {'title': '', 'start_at': 0, 'end_at': 0},
    groups: const {
      'title': ['title'],
      'details': ['description', 'location'],
      'time': ['all_day', 'start_at', 'end_at'],
      'recurrence': ['recurrence', 'exdates'],
      'tags': ['tag_ids'],
      'reminder': ['reminder_minutes', 'reminder_devices'],
      'project': ['project_id'],
    },
  ),
  'finance_entries': EntitySchema(
    table: 'finance_entries',
    tableOf: (db) => db.financeEntries,
    insertDefaults: const {'kind': 'expense', 'amount_cents': 0, 'date': '1970-01-01'},
    groups: const {
      'amount': ['kind', 'amount_cents'],
      'title': ['title'],
      'date': ['date'],
      'tags': ['tag_ids'],
      'link': ['saving_goal_id', 'recurring_id'],
    },
  ),
  'finance_recurring': EntitySchema(
    table: 'finance_recurring',
    tableOf: (db) => db.financeRecurring,
    insertDefaults: const {
      'kind': 'expense',
      'amount_cents': 0,
      'freq': 'monthly',
      'start_date': '1970-01-01',
    },
    groups: const {
      'amount': ['kind', 'amount_cents'],
      'title': ['title'],
      'tags': ['tag_ids'],
      'schedule': ['freq', 'interval_count', 'start_date', 'end_date'],
    },
  ),
  'daily_reports': EntitySchema(
    table: 'daily_reports',
    tableOf: (db) => db.dailyReports,
    insertDefaults: const {'date': '1970-01-01'},
    groups: const {
      'date': ['date'],
      'successes': ['successes'],
      'learned': ['learned'],
      'checks': ['calendar_done', 'kcal_goal_met', 'water_goal_met'],
      'sleep': ['slept_at', 'woke_at'],
      'activities': ['activities'],
    },
  ),
  'habits': EntitySchema(
    table: 'habits',
    tableOf: (db) => db.habits,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'color': ['color_index'],
      'schedule': ['weekdays'],
      'archived': ['archived'],
    },
  ),
  'habit_checks': EntitySchema(
    table: 'habit_checks',
    tableOf: (db) => db.habitChecks,
    insertDefaults: const {'habit_id': '', 'date': '1970-01-01'},
    groups: const {
      'key': ['habit_id', 'date'],
      'done': ['done'],
    },
  ),
  'projects': EntitySchema(
    table: 'projects',
    tableOf: (db) => db.projects,
    insertDefaults: const {'name': ''},
    groups: const {
      'name': ['name'],
      'description': ['description'],
      'deadline': ['deadline'],
      'color': ['color_index'],
      'status': ['status'],
    },
  ),
  'saving_goals': EntitySchema(
    table: 'saving_goals',
    tableOf: (db) => db.savingGoals,
    insertDefaults: const {'name': '', 'target_cents': 0},
    groups: const {
      'name': ['name'],
      'target': ['target_cents', 'target_date'],
    },
  ),
};
