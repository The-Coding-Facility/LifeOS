import 'dart:io';

import 'package:drift/native.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:test/test.dart';

void main() {
  const newTables = [
    'tags',
    'calendar_events',
    'finance_entries',
    'finance_recurring',
    'saving_goals',
  ];

  Future<void> expectTablesUsable(LifeosDatabase db) async {
    for (final table in newTables) {
      final rows = await db.customSelect('SELECT COUNT(*) AS c FROM $table').get();
      expect(rows.single.read<int>('c'), 0, reason: table);
    }
  }

  test('neue Datenbank hat Schema 3 mit allen Tabellen', () async {
    final db = LifeosDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 3);
    await expectTablesUsable(db);
  });

  test('Datenbank mit Schema 2 bekommt die neuen Tabellen', () async {
    final dir = await Directory.systemTemp.createTemp('lifeos_migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.db');

    final old = LifeosDatabase(NativeDatabase(file));
    await old.customSelect('SELECT 1').get();
    await old.into(old.tasks).insert(
          TasksCompanion.insert(
            id: 'bleibt',
            title: 'Alte Aufgabe',
            createdAt: 1,
            createdBy: 'a',
            updatedHlc: 'h',
            updatedBy: 'a',
          ),
        );
    for (final table in newTables) {
      await old.customStatement('DROP TABLE $table');
    }
    await old.customStatement('PRAGMA user_version = 2');
    await old.close();

    final upgraded = LifeosDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await expectTablesUsable(upgraded);
    final tasks = await upgraded.select(upgraded.tasks).get();
    expect(tasks.single.id, 'bleibt');
  });
}
