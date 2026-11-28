import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:test/test.dart';

void main() {
  late LifeosDatabase db;
  late RecordWriter writer;

  setUp(() async {
    db = LifeosDatabase(NativeDatabase.memory());
    writer = RecordWriter(db, await ChangeRecorder.open(db));
  });

  tearDown(() => db.close());

  const groups = {
    'name': ['name'],
    'category': ['category'],
  };

  test('anlegen, ändern, löschen mit Protokoll', () async {
    await db.transaction(() async {
      await writer.insert(
        'exercises',
        db.exercises,
        'e1',
        RecordWriter.allGroups(groups, {'name': 'Bankdrücken', 'category': 'strength'}),
      );
    });
    var row = await (db.select(db.exercises)..where((e) => e.id.equals('e1'))).getSingle();
    expect(row.name, 'Bankdrücken');

    final changed = RecordWriter.changedGroups(
      groups,
      {'name': 'Bankdrücken', 'category': 'endurance'},
      {'name': row.name, 'category': row.category},
    );
    expect(changed.keys, ['category']);
    await db.transaction(() => writer.update('exercises', db.exercises, 'e1', changed));
    row = await (db.select(db.exercises)..where((e) => e.id.equals('e1'))).getSingle();
    expect(row.category, 'endurance');

    expect(await db.transaction(() => writer.delete('exercises', db.exercises, 'e1')), isTrue);
    expect(await db.transaction(() => writer.delete('exercises', db.exercises, 'e1')), isFalse);

    final log = await (db.select(db.changeLog)..orderBy([(e) => OrderingTerm.asc(e.seq)])).get();
    expect(log.map((e) => e.op), ['upsert', 'upsert', 'delete']);
    expect((jsonDecode(log[1].payload) as Map).keys, ['category']);
  });

  test('Kommazahlen und leere Werte', () async {
    await db.transaction(
      () => writer.insert(
        'body_measurements',
        db.bodyMeasurements,
        'b1',
        {
          'date': {'date': '2026-11-28'},
          'weight': {'weight': 81.4},
          'height': {'height': null},
        },
      ),
    );
    final row = await (db.select(db.bodyMeasurements)..where((b) => b.id.equals('b1'))).getSingle();
    expect(row.weight, 81.4);
    expect(row.height, isNull);
  });
}
