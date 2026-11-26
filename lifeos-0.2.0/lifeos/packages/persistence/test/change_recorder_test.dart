import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:test/test.dart';

void main() {
  late LifeosDatabase db;
  late ChangeRecorder recorder;
  var wall = 1000;

  Future<List<ChangeLogEntry>> log() {
    final query = db.select(db.changeLog)
      ..orderBy([(entry) => OrderingTerm.asc(entry.seq)]);
    return query.get();
  }

  setUp(() async {
    wall = 1000;
    db = LifeosDatabase(NativeDatabase.memory());
    recorder = await ChangeRecorder.open(db, wallClock: () => wall);
  });

  tearDown(() => db.close());

  test('Geräte-ID bleibt beim erneuten Öffnen gleich', () async {
    final again = await ChangeRecorder.open(db);
    expect(again.deviceId, recorder.deviceId);
  });

  test('jede Änderung bekommt eine fortlaufende Nummer', () async {
    await recorder.record(
      entity: 'tasks',
      recordId: 'a',
      op: ChangeOp.upsert,
      groups: {'title': {'title': 'Eins'}},
    );
    await recorder.record(
      entity: 'tasks',
      recordId: 'b',
      op: ChangeOp.upsert,
      groups: {'title': {'title': 'Zwei'}},
    );
    final entries = await log();
    expect(entries.map((entry) => entry.seq), [1, 2]);
    expect(entries.every((entry) => entry.originDevice == recorder.deviceId), isTrue);
  });

  test('Vorgänger-HLC wird je Feldgruppe gemerkt', () async {
    final first = await recorder.record(
      entity: 'tasks',
      recordId: 'a',
      op: ChangeOp.upsert,
      groups: {
        'title': {'title': 'Alt'},
        'done': {'done': false},
      },
    );
    wall = 2000;
    await recorder.record(
      entity: 'tasks',
      recordId: 'a',
      op: ChangeOp.upsert,
      groups: {'title': {'title': 'Neu'}},
    );

    final second = (await log()).last;
    final payload = jsonDecode(second.payload) as Map<String, dynamic>;
    final title = payload['title'] as Map<String, dynamic>;
    expect(title['prev'], first.pack());
    expect((title['values'] as Map<String, dynamic>)['title'], 'Neu');
    expect(payload.containsKey('done'), isFalse);
  });

  test('HLC läuft nach erneutem Öffnen nicht rückwärts', () async {
    wall = 5000;
    final before = await recorder.record(
      entity: 'notes',
      recordId: 'n',
      op: ChangeOp.upsert,
      groups: {'body': {'body': 'x'}},
    );
    wall = 10;
    final reopened = await ChangeRecorder.open(db, wallClock: () => wall);
    final after = await reopened.record(
      entity: 'notes',
      recordId: 'n',
      op: ChangeOp.upsert,
      groups: {'body': {'body': 'y'}},
    );
    expect(after > before, isTrue);
  });

  test('abgebrochene Transaktion hinterlässt keinen Protokolleintrag', () async {
    await expectLater(
      db.transaction(() async {
        await recorder.record(
          entity: 'tasks',
          recordId: 'a',
          op: ChangeOp.upsert,
          groups: {'title': {'title': 'Wird verworfen'}},
        );
        throw StateError('Abbruch');
      }),
      throwsStateError,
    );
    expect(await log(), isEmpty);
    expect(await db.select(db.rowClocks).get(), isEmpty);
  });

  test('leere Feldgruppen werden abgelehnt', () {
    expect(
      () => recorder.record(entity: 'tasks', recordId: 'a', op: ChangeOp.upsert, groups: {}),
      throwsArgumentError,
    );
  });
}
