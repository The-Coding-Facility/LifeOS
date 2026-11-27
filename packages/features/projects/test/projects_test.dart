import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_projects/lifeos_projects.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

TaskItem task(String id, {bool done = false}) =>
    TaskItem(id: id, title: id, done: done, createdAt: DateTime.utc(2026), projectId: 'p');

void main() {
  final today = DateTime(2026, 11, 27);

  test('Fortschritt aus Unterpunkten', () {
    expect(progressOf(const []), 0);
    expect(progressOf([task('a', done: true), task('b'), task('c', done: true), task('d')]), 0.5);
  });

  test('Deadline-Texte', () {
    expect(deadlineText(null, today), isNull);
    expect(deadlineText(today, today), 'Heute fällig');
    expect(deadlineText(DateTime(2026, 11, 28), today), 'Noch 1 Tag');
    expect(deadlineText(DateTime(2026, 12, 31), today), 'Noch 34 Tage');
    expect(deadlineText(DateTime(2026, 11, 26), today), 'Seit 1 Tag überfällig');
    expect(deadlineText(DateTime(2026, 11, 20), today), 'Seit 7 Tagen überfällig');
  });

  group('Speichern', () {
    late LifeosDatabase db;
    late ProjectRepository projects;
    late TaskRepository tasks;

    setUp(() async {
      db = LifeosDatabase(NativeDatabase.memory());
      final recorder = await ChangeRecorder.open(db);
      projects = ProjectRepository(db, recorder);
      tasks = TaskRepository(db, recorder);
    });

    tearDown(() => db.close());

    test('Anlegen, Unterpunkte, Abschließen, Löschen', () async {
      final id = await projects.create(ProjectDraft(name: 'Umzug', deadline: DateTime(2027, 1, 15)));
      await tasks.create('Kartons besorgen', projectId: id);
      final second = await tasks.create('Ummelden', projectId: id);
      await tasks.setDone(second, true);

      final sub = await tasks.watchByProject(id).first;
      expect(progressOf(sub), 0.5);
      expect(await tasks.watchAll().first, isEmpty, reason: 'Unterpunkte nicht in der Aufgabenliste');

      await projects.setStatus(id, ProjectStatus.done);
      expect((await projects.watchAll().first).single.status, ProjectStatus.done);

      await projects.update(id, const ProjectDraft(name: 'Umzug nach Köln'));
      final updated = (await projects.watchAll().first).single;
      expect(updated.name, 'Umzug nach Köln');
      expect(updated.deadline, isNull);
      expect(updated.status, ProjectStatus.done, reason: 'Bearbeiten ändert den Status nicht');

      await projects.delete(id);
      expect(await projects.watchAll().first, isEmpty);
    });

    test('Projekte mit Deadline zuerst', () async {
      await projects.create(const ProjectDraft(name: 'Ohne'));
      await projects.create(ProjectDraft(name: 'Später', deadline: DateTime(2027, 6, 1)));
      await projects.create(ProjectDraft(name: 'Bald', deadline: DateTime(2026, 12, 1)));
      expect([for (final p in await projects.watchAll().first) p.name], ['Bald', 'Später', 'Ohne']);
    });
  });

  testWidgets('Liste zeigt Fortschritt und Deadline', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => Stream.value([Project(id: 'p', name: 'Marathon', deadline: DateTime(2026, 12, 7))]),
        ),
        projectTasksProvider.overrideWith(
          (ref, id) => Stream.value([task('a', done: true), task('b'), task('c'), task('d')]),
        ),
      ],
      child: MaterialApp(
        theme: buildLifeosTheme(Brightness.light),
        home: ProjectsPage(onOpenProject: (_) {}, clock: () => today),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Marathon'), findsOneWidget);
    expect(find.text('25 %'), findsOneWidget);
    expect(find.text('1 von 4 erledigt · bis 07.12.2026 · Noch 10 Tage'), findsOneWidget);
  });
}
