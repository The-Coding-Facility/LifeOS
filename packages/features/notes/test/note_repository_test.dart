import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

void main() {
  late LifeosDatabase db;
  late NoteRepository repository;

  setUp(() async {
    db = LifeosDatabase(NativeDatabase.memory());
    repository = NoteRepository(db, await ChangeRecorder.open(db));
  });

  tearDown(() => db.close());

  Future<List<ChangeLogEntry>> log() {
    final query = db.select(db.changeLog)
      ..orderBy([(entry) => OrderingTerm.asc(entry.seq)]);
    return query.get();
  }

  test('Anlegen und Bearbeiten', () async {
    final id = await repository.create();
    await repository.update(id, title: 'Einkauf', body: '- Milch\n- Brot');
    final note = await repository.watch(id).first;
    expect(note, isNotNull);
    expect(note!.title, 'Einkauf');
    expect(note.body, '- Milch\n- Brot');
  });

  test('nur geänderte Feldgruppen landen im Protokoll', () async {
    final id = await repository.create(title: 'Titel', body: 'Text');
    await repository.update(id, title: 'Titel', body: 'Neuer Text');
    final entries = await log();
    expect(entries, hasLength(2));
    final payload = jsonDecode(entries[1].payload) as Map<String, dynamic>;
    expect(payload.keys, ['body']);
    expect((payload['body'] as Map<String, dynamic>)['prev'], entries[0].hlc);
  });

  test('unveränderter Inhalt schreibt nichts', () async {
    final id = await repository.create(title: 'A', body: 'B');
    await repository.update(id, title: 'A', body: 'B');
    expect(await log(), hasLength(1));
  });

  test('Löschen macht die Notiz unsichtbar und protokolliert es', () async {
    final id = await repository.create(title: 'Weg damit');
    await repository.delete(id);
    expect(await repository.watch(id).first, isNull);
    expect(await repository.watchAll().first, isEmpty);
    expect((await log()).last.op, 'delete');
  });

  test('zuletzt geänderte Notiz steht oben', () async {
    final first = await repository.create(title: 'Erste');
    await repository.create(title: 'Zweite');
    await repository.update(first, body: 'jetzt geändert');
    final titles = (await repository.watchAll().first).map((note) => note.title);
    expect(titles, ['Erste', 'Zweite']);
  });

  test('displayTitle nutzt die erste Zeile, wenn der Titel fehlt', () {
    final now = DateTime.utc(2026);
    final note = NoteItem(id: 'x', title: ' ', body: '\nErste Zeile\nZweite', createdAt: now, updatedAt: now);
    expect(note.displayTitle, 'Erste Zeile');
    expect(note.isEmpty, isFalse);
  });
}
