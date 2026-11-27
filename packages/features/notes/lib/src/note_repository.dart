import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'note_item.dart';

/// Lesen und Schreiben von Notizen. Jede Änderung wird protokolliert.
///
/// Feldgruppen: `title` und `body`. Gleichzeitige Änderungen am Text werden
/// später als Konfliktkopie behandelt (Architektur Abschnitt 7).
class NoteRepository {
  NoteRepository(this._db, this._recorder);

  static const String entity = 'notes';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// Alle nicht gelöschten Notizen, zuletzt geänderte zuerst.
  Stream<List<NoteItem>> watchAll() {
    final query = _db.select(_db.notes)
      ..where((note) => note.deletedHlc.isNull())
      ..orderBy([(note) => OrderingTerm.desc(note.updatedHlc)]);
    return query.watch().map(
          (rows) => rows.map(_toItem).toList(growable: false),
        );
  }

  /// Eine Notiz oder `null`, wenn sie nicht (mehr) existiert.
  Stream<NoteItem?> watch(String id) {
    final query = _db.select(_db.notes)
      ..where((note) => note.id.equals(id) & note.deletedHlc.isNull());
    return query.watchSingleOrNull().map((row) => row == null ? null : _toItem(row));
  }

  /// Angeheftete Notizen für die Übersicht, zuletzt geänderte zuerst.
  Stream<List<NoteItem>> watchPinned() {
    final query = _db.select(_db.notes)
      ..where((note) => note.deletedHlc.isNull() & note.pinned.equals(true))
      ..orderBy([(note) => OrderingTerm.desc(note.updatedHlc)]);
    return query.watch().map((rows) => rows.map(_toItem).toList(growable: false));
  }

  /// Notizen eines Projekts, zuletzt geänderte zuerst.
  Stream<List<NoteItem>> watchByProject(String projectId) {
    final query = _db.select(_db.notes)
      ..where((note) => note.deletedHlc.isNull() & note.projectId.equals(projectId))
      ..orderBy([(note) => OrderingTerm.desc(note.updatedHlc)]);
    return query.watch().map((rows) => rows.map(_toItem).toList(growable: false));
  }

  /// Heftet eine Notiz an die Übersicht an oder löst sie.
  Future<void> setPinned(String id, bool pinned) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null || current.pinned == pinned) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'pinned': {'pinned': pinned},
        },
      );
      await (_db.update(_db.notes)..where((note) => note.id.equals(id))).write(
        NotesCompanion(
          pinned: Value(pinned),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Legt eine Notiz an. Mit [projectId] erscheint sie im Projekt.
  Future<String> create({String title = '', String body = '', String? projectId}) {
    return _db.transaction(() async {
      final id = Ids.newId();
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'title': {'title': title},
          'body': {'body': body},
          if (projectId != null) 'project': {'project_id': projectId},
        },
      );
      await _db.into(_db.notes).insert(
            NotesCompanion.insert(
              id: id,
              title: Value(title),
              body: Value(body),
              projectId: Value(projectId),
              createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
  }

  /// Speichert nur die Feldgruppen, die sich wirklich geändert haben.
  Future<void> update(String id, {String? title, String? body}) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final newTitle = title != null && title != current.title ? title : null;
      final newBody = body != null && body != current.body ? body : null;
      if (newTitle == null && newBody == null) return;

      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          if (newTitle != null) 'title': {'title': newTitle},
          if (newBody != null) 'body': {'body': newBody},
        },
      );
      await (_db.update(_db.notes)..where((note) => note.id.equals(id))).write(
        NotesCompanion(
          title: newTitle == null ? const Value.absent() : Value(newTitle),
          body: newBody == null ? const Value.absent() : Value(newBody),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Löscht eine Notiz als Tombstone.
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
      await (_db.update(_db.notes)..where((note) => note.id.equals(id))).write(
        NotesCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  Future<NoteRow?> _findActive(String id) {
    final query = _db.select(_db.notes)
      ..where((note) => note.id.equals(id) & note.deletedHlc.isNull());
    return query.getSingleOrNull();
  }

  static NoteItem _toItem(NoteRow row) => NoteItem(
        id: row.id,
        title: row.title,
        body: row.body,
        projectId: row.projectId,
        pinned: row.pinned,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          Hlc.parse(row.updatedHlc).millis,
          isUtc: true,
        ),
      );
}
