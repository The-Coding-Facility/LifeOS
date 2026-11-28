import 'dart:io';

import 'package:drift/native.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:test/test.dart';

void main() {
  const v3Tables = [
    'tags',
    'calendar_events',
    'finance_entries',
    'finance_recurring',
    'saving_goals',
  ];
  const v4Tables = ['daily_reports', 'habits', 'habit_checks', 'projects'];
  const v5Tables = ['ingredients', 'recipes', 'shopping_items'];
  const v6Tables = [
    'learning_areas',
    'glossary_entries',
    'flashcards',
    'learning_resources',
    'study_sessions',
    'body_measurements',
    'nutrition_logs',
    'sport_goals',
    'exercises',
    'training_plans',
    'workout_sessions',
  ];

  Future<void> expectTablesUsable(LifeosDatabase db) async {
    for (final table in [...v3Tables, ...v4Tables, ...v5Tables, ...v6Tables]) {
      final rows = await db.customSelect('SELECT COUNT(*) AS c FROM $table').get();
      expect(rows.single.read<int>('c'), 0, reason: table);
    }
    // Neue Spalten von Schema 4 sind abfragbar.
    await db.customSelect('SELECT project_id, pinned FROM notes').get();
    await db.customSelect('SELECT project_id, training_plan_id FROM calendar_events').get();
    await db.customSelect('SELECT learning_area_id FROM notes').get();
  }

  /// Legt eine Datenbank im Stand von Schema [version] an (mit einer
  /// alten Aufgabe), indem eine neue zurückgebaut wird.
  Future<File> databaseAtVersion(int version) async {
    final dir = await Directory.systemTemp.createTemp('lifeos_migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.db');
    final db = LifeosDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    await db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: 'bleibt',
            title: 'Alte Aufgabe',
            createdAt: 1,
            createdBy: 'a',
            updatedHlc: 'h',
            updatedBy: 'a',
          ),
        );
    for (final table in v6Tables) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('ALTER TABLE notes DROP COLUMN learning_area_id');
    await db.customStatement('ALTER TABLE calendar_events DROP COLUMN training_plan_id');
    if (version <= 4) {
      for (final table in v5Tables) {
        await db.customStatement('DROP TABLE $table');
      }
    }
    if (version <= 3) {
      for (final table in v4Tables) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('ALTER TABLE notes DROP COLUMN project_id');
      await db.customStatement('ALTER TABLE notes DROP COLUMN pinned');
      if (version <= 2) {
        for (final table in v3Tables) {
          await db.customStatement('DROP TABLE $table');
        }
      } else {
        await db.customStatement('ALTER TABLE calendar_events DROP COLUMN project_id');
      }
    }
    await db.customStatement('PRAGMA user_version = $version');
    await db.close();
    return file;
  }

  test('neue Datenbank hat Schema 6 mit allen Tabellen', () async {
    final db = LifeosDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 6);
    await expectTablesUsable(db);
  });

  for (final version in [2, 3, 4, 5]) {
    test('Datenbank mit Schema $version wird auf 6 gebracht', () async {
      final file = await databaseAtVersion(version);
      final upgraded = LifeosDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      await expectTablesUsable(upgraded);
      final tasks = await upgraded.select(upgraded.tasks).get();
      expect(tasks.single.id, 'bleibt');
    });
  }
}
