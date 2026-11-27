import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'task_item.dart';

/// Lesen und Schreiben von Aufgaben. Jede Änderung wird protokolliert.
///
/// Feldgruppen (Einheit der Konfliktauflösung, siehe Architektur Abschnitt 7):
/// `title`, `details`, `done` (Haken und Zeitpunkt), `due`, `project`.
class TaskRepository {
  TaskRepository(this._db, this._recorder);

  static const String entity = 'tasks';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// Alle nicht gelöschten Aufgaben ohne Projekt: offene zuerst, neueste
  /// oben. Unterpunkte von Projekten erscheinen nur im Projekt.
  Stream<List<TaskItem>> watchAll() {
    final query = _db.select(_db.tasks)
      ..where((task) => task.deletedHlc.isNull() & task.projectId.isNull())
      ..orderBy([
        (task) => OrderingTerm.asc(task.done),
        (task) => OrderingTerm.desc(task.createdAt),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toItem).toList(growable: false),
        );
  }

  /// Unterpunkte eines Projekts in der Reihenfolge des Anlegens.
  Stream<List<TaskItem>> watchByProject(String projectId) {
    final query = _db.select(_db.tasks)
      ..where((task) => task.deletedHlc.isNull() & task.projectId.equals(projectId))
      ..orderBy([(task) => OrderingTerm.asc(task.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(_toItem).toList(growable: false),
        );
  }

  /// Legt eine Aufgabe an und gibt ihre ID zurück. Mit [projectId] wird sie
  /// ein Unterpunkt dieses Projekts.
  Future<String> create(String title, {String? details, String? projectId}) {
    final cleanTitle = _requireTitle(title);
    return _db.transaction(() async {
      final id = Ids.newId();
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'title': {'title': cleanTitle},
          'details': {'details': details},
          'done': {'done': false, 'done_at': null},
          if (projectId != null) 'project': {'project_id': projectId},
        },
      );
      await _db.into(_db.tasks).insert(
            TasksCompanion.insert(
              id: id,
              title: cleanTitle,
              details: Value(details),
              projectId: Value(projectId),
              createdAt: _nowMillis(),
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
  }

  Future<void> rename(String id, String title) {
    final cleanTitle = _requireTitle(title);
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null || current.title == cleanTitle) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'title': {'title': cleanTitle},
        },
      );
      await _write(id, hlc, TasksCompanion(title: Value(cleanTitle)));
    });
  }

  Future<void> setDone(String id, bool done) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null || current.done == done) return;
      final doneAt = done ? _nowMillis() : null;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'done': {'done': done, 'done_at': doneAt},
        },
      );
      await _write(id, hlc, TasksCompanion(done: Value(done), doneAt: Value(doneAt)));
    });
  }

  /// Löscht eine Aufgabe als Tombstone. Sie bleibt für den Sync erhalten.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await _write(id, hlc, TasksCompanion(deletedHlc: Value(hlc.pack())));
    });
  }

  Future<TaskRow?> _findActive(String id) {
    final query = _db.select(_db.tasks)
      ..where((task) => task.id.equals(id) & task.deletedHlc.isNull());
    return query.getSingleOrNull();
  }

  Future<void> _write(String id, Hlc hlc, TasksCompanion changes) async {
    await (_db.update(_db.tasks)..where((task) => task.id.equals(id))).write(
      changes.copyWith(
        updatedHlc: Value(hlc.pack()),
        updatedBy: Value(_recorder.deviceId),
      ),
    );
  }

  static String _requireTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Der Titel einer Aufgabe darf nicht leer sein.');
    }
    return trimmed;
  }

  static int _nowMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static TaskItem _toItem(TaskRow row) => TaskItem(
        id: row.id,
        title: row.title,
        details: row.details,
        done: row.done,
        doneAt: row.doneAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.doneAt!, isUtc: true),
        dueDate: row.dueDate,
        projectId: row.projectId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      );
}
