import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Lesen und Schreiben von Projekten.
///
/// Feldgruppen: `name`, `description`, `deadline`, `color`, `status`.
/// Unterpunkte sind Aufgaben mit `project_id` (siehe `TaskRepository`).
class ProjectRepository {
  ProjectRepository(this._db, this._recorder);

  static const String entity = 'projects';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  static const Map<String, List<String>> _groups = {
    'name': ['name'],
    'description': ['description'],
    'deadline': ['deadline'],
    'color': ['color_index'],
    'status': ['status'],
  };

  /// Alle Projekte: nächste Deadline zuerst, ohne Deadline danach.
  Stream<List<Project>> watchAll() {
    final query = _db.select(_db.projects)..where((project) => project.deletedHlc.isNull());
    return query.watch().map((rows) {
      final projects = [for (final row in rows) _toProject(row)];
      projects.sort((a, b) {
        final ad = a.deadline;
        final bd = b.deadline;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return projects;
    });
  }

  Future<String> create(ProjectDraft draft) {
    return _db.transaction(() async {
      final id = Ids.newId();
      final columns = {..._columnsOf(draft), 'status': ProjectStatus.active.key};
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          for (final MapEntry(key: group, value: names) in _groups.entries)
            group: {for (final name in names) name: columns[name]},
        },
      );
      await _db.into(_db.projects).insert(
            ProjectsCompanion.insert(
              id: id,
              name: columns['name']! as String,
              description: Value(columns['description']! as String),
              deadline: Value(columns['deadline'] as String?),
              colorIndex: Value(columns['color_index']! as int),
              createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
  }

  Future<void> update(String id, ProjectDraft draft) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null) return;
      final wanted = {..._columnsOf(draft), 'status': row.status};
      final existing = <String, Object?>{
        'name': row.name,
        'description': row.description,
        'deadline': row.deadline,
        'color_index': row.colorIndex,
        'status': row.status,
      };
      final groups = {
        for (final MapEntry(key: group, value: names) in _groups.entries)
          if (names.any((name) => wanted[name] != existing[name]))
            group: {for (final name in names) name: wanted[name]},
      };
      if (groups.isEmpty) return;
      await _write(id, groups);
    });
  }

  Future<void> setStatus(String id, ProjectStatus status) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null || row.status == status.key) return;
      await _write(id, {
        'status': {'status': status.key},
      });
    });
  }

  /// Löscht ein Projekt als Tombstone. Unterpunkte löscht die Oberfläche
  /// vorher über das Aufgabenmodul; Notizen und Termine bleiben erhalten.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await (_db.update(_db.projects)..where((project) => project.id.equals(id))).write(
        ProjectsCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  Future<void> _write(String id, Map<String, Map<String, Object?>> groups) async {
    final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
    final values = {for (final group in groups.values) ...group};
    await (_db.update(_db.projects)..where((project) => project.id.equals(id))).write(
      ProjectsCompanion(
        name: values.containsKey('name') ? Value(values['name']! as String) : const Value.absent(),
        description:
            values.containsKey('description') ? Value(values['description']! as String) : const Value.absent(),
        deadline: values.containsKey('deadline') ? Value(values['deadline'] as String?) : const Value.absent(),
        colorIndex: values.containsKey('color_index') ? Value(values['color_index']! as int) : const Value.absent(),
        status: values.containsKey('status') ? Value(values['status']! as String) : const Value.absent(),
        updatedHlc: Value(hlc.pack()),
        updatedBy: Value(_recorder.deviceId),
      ),
    );
  }

  Future<ProjectRow?> _findActive(String id) =>
      (_db.select(_db.projects)..where((project) => project.id.equals(id) & project.deletedHlc.isNull()))
          .getSingleOrNull();

  static Map<String, Object?> _columnsOf(ProjectDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty) throw ArgumentError('Ein Projekt braucht einen Namen.');
    return {
      'name': name,
      'description': draft.description.trim(),
      'deadline': draft.deadline == null ? null : isoDate(draft.deadline!),
      'color_index': draft.colorIndex,
    };
  }

  static Project _toProject(ProjectRow row) {
    DateTime? deadline;
    final raw = row.deadline;
    if (raw != null) {
      try {
        deadline = parseIsoDate(raw);
      } on FormatException {
        deadline = null;
      }
    }
    return Project(
      id: row.id,
      name: row.name,
      description: row.description,
      deadline: deadline,
      colorIndex: row.colorIndex,
      status: ProjectStatus.fromKey(row.status),
    );
  }
}
