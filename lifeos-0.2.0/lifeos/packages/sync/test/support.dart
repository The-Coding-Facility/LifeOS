import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

/// Ein simuliertes Gerät mit eigener In-Memory-Datenbank.
class TestDevice {
  TestDevice._(this.db, this.recorder, this.engine);

  static Future<TestDevice> create({int Function()? wallClock}) async {
    final db = LifeosDatabase(NativeDatabase.memory());
    final recorder = await ChangeRecorder.open(db, wallClock: wallClock);
    return TestDevice._(db, recorder, SyncEngine(db, recorder));
  }

  final LifeosDatabase db;
  final ChangeRecorder recorder;
  final SyncEngine engine;

  /// Schreibt eine Aufgabe genau so, wie es das Repository tut.
  Future<String> createTask(String title) => db.transaction(() async {
        final id = Ids.newId();
        final hlc = await recorder.record(
          entity: 'tasks',
          recordId: id,
          op: ChangeOp.upsert,
          groups: {
            'title': {'title': title},
            'details': {'details': null},
            'done': {'done': false, 'done_at': null},
          },
        );
        await db.into(db.tasks).insert(
              TasksCompanion.insert(
                id: id,
                title: title,
                createdAt: hlc.millis,
                createdBy: recorder.deviceId,
                updatedHlc: hlc.pack(),
                updatedBy: recorder.deviceId,
              ),
            );
        return id;
      });

  Future<void> renameTask(String id, String title) => db.transaction(() async {
        final hlc = await recorder.record(
          entity: 'tasks',
          recordId: id,
          op: ChangeOp.upsert,
          groups: {
            'title': {'title': title},
          },
        );
        await (db.update(db.tasks)..where((task) => task.id.equals(id))).write(
          TasksCompanion(title: Value(title), updatedHlc: Value(hlc.pack())),
        );
      });

  Future<void> setDone(String id, bool done) => db.transaction(() async {
        final hlc = await recorder.record(
          entity: 'tasks',
          recordId: id,
          op: ChangeOp.upsert,
          groups: {
            'done': {'done': done, 'done_at': done ? 1 : null},
          },
        );
        await (db.update(db.tasks)..where((task) => task.id.equals(id))).write(
          TasksCompanion(done: Value(done), doneAt: Value(done ? 1 : null), updatedHlc: Value(hlc.pack())),
        );
      });

  Future<void> deleteTask(String id) => db.transaction(() async {
        final hlc = await recorder.record(
          entity: 'tasks',
          recordId: id,
          op: ChangeOp.delete,
          groups: {
            deletedFieldGroup: {'deleted': true},
          },
        );
        await (db.update(db.tasks)..where((task) => task.id.equals(id))).write(
          TasksCompanion(deletedHlc: Value(hlc.pack()), updatedHlc: Value(hlc.pack())),
        );
      });

  Future<TaskRow?> task(String id) =>
      (db.select(db.tasks)..where((task) => task.id.equals(id))).getSingleOrNull();

  /// Holt alles, was [other] hat und dieses Gerät noch nicht.
  Future<int> pullFrom(TestDevice other) async {
    final entries = await other.engine.entriesMissingFrom(await engine.versionVector());
    return engine.applyEntries(entries);
  }

  Future<void> close() => db.close();
}
