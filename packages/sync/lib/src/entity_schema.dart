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
    },
  ),
};
