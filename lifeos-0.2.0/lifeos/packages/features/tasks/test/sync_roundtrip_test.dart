import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

/// Prüft, dass die Änderungen des echten Repositorys vom Sync verstanden werden.
void main() {
  late LifeosDatabase dbA;
  late LifeosDatabase dbB;
  late TaskRepository repoA;
  late TaskRepository repoB;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUp(() async {
    dbA = LifeosDatabase(NativeDatabase.memory());
    dbB = LifeosDatabase(NativeDatabase.memory());
    final recorderA = await ChangeRecorder.open(dbA);
    final recorderB = await ChangeRecorder.open(dbB);
    repoA = TaskRepository(dbA, recorderA);
    repoB = TaskRepository(dbB, recorderB);
    engineA = SyncEngine(dbA, recorderA);
    engineB = SyncEngine(dbB, recorderB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  Future<void> exchange() async {
    await engineB.applyEntries(await engineA.entriesMissingFrom(await engineB.versionVector()));
    await engineA.applyEntries(await engineB.entriesMissingFrom(await engineA.versionVector()));
  }

  String describe(List<TaskItem> items) {
    final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
    return sorted.map((task) => '${task.id}:${task.title}:${task.done}').join('|');
  }

  test('Anlegen, Abhaken, Umbenennen und Löschen landen auf beiden Geräten gleich', () async {
    final milk = await repoA.create('Milch');
    final bread = await repoB.create('Brot');
    await exchange();

    await repoB.setDone(milk, true);
    await repoA.rename(bread, 'Vollkornbrot');
    final cheese = await repoA.create('Käse');
    await exchange();
    await repoB.delete(cheese);
    await exchange();

    final onA = await repoA.watchAll().first;
    final onB = await repoB.watchAll().first;
    expect(describe(onA), describe(onB));
    expect(onA.map((task) => task.title).toSet(), {'Milch', 'Vollkornbrot'});
    expect(onA.firstWhere((task) => task.id == milk).done, isTrue);
  });
}
