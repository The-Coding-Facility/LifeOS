import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

void main() {
  late LifeosDatabase db;
  late TaskRepository repository;

  setUp(() async {
    db = LifeosDatabase(NativeDatabase.memory());
    repository = TaskRepository(db, await ChangeRecorder.open(db));
  });

  tearDown(() => db.close());

  Future<List<ChangeLogEntry>> log() {
    final query = db.select(db.changeLog)
      ..orderBy([(entry) => OrderingTerm.asc(entry.seq)]);
    return query.get();
  }

  test('Anlegen, abhaken und löschen schreibt je einen Protokolleintrag', () async {
    final id = await repository.create('  Einkaufen  ');
    final created = (await repository.watchAll().first).single;
    expect(created.title, 'Einkaufen');
    expect(created.done, isFalse);

    await repository.setDone(id, true);
    expect((await repository.watchAll().first).single.done, isTrue);

    await repository.delete(id);
    expect(await repository.watchAll().first, isEmpty);

    final entries = await log();
    expect(entries.map((entry) => entry.op), ['upsert', 'upsert', 'delete']);
    expect(entries.every((entry) => entry.recordId == id), isTrue);
    expect(entries.every((entry) => entry.entity == TaskRepository.entity), isTrue);
  });

  test('Abhaken merkt den Vorgänger der Feldgruppe done', () async {
    final id = await repository.create('Sport');
    await repository.setDone(id, true);
    await repository.setDone(id, false);

    final entries = await log();
    final second = jsonDecode(entries[1].payload) as Map<String, dynamic>;
    final third = jsonDecode(entries[2].payload) as Map<String, dynamic>;
    expect((second['done'] as Map<String, dynamic>)['prev'], entries[0].hlc);
    expect((third['done'] as Map<String, dynamic>)['prev'], entries[1].hlc);
    expect(second.containsKey('title'), isFalse);
  });

  test('Änderungen ohne Wirkung schreiben nichts ins Protokoll', () async {
    final id = await repository.create('Lesen');
    await repository.rename(id, 'Lesen');
    await repository.setDone(id, false);
    expect(await log(), hasLength(1));
  });

  test('gelöschte Aufgaben lassen sich nicht mehr ändern', () async {
    final id = await repository.create('Alt');
    await repository.delete(id);
    await repository.rename(id, 'Neu');
    await repository.setDone(id, true);
    await repository.delete(id);
    expect(await log(), hasLength(2));
  });

  test('leerer Titel wird abgelehnt', () {
    expect(() => repository.create('   '), throwsArgumentError);
  });

  test('offene Aufgaben stehen vor erledigten', () async {
    final first = await repository.create('Erste');
    await repository.create('Zweite');
    await repository.setDone(first, true);
    final titles = (await repository.watchAll().first).map((task) => task.title);
    expect(titles, ['Zweite', 'Erste']);
  });
}
