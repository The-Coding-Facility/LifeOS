import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

Set<String> days(List<DateTime> dates) => {for (final date in dates) isoDate(date)};

void main() {
  // 27.11.2026 ist ein Freitag.
  final friday = DateTime(2026, 11, 27);
  final saturday = DateTime(2026, 11, 28);
  final monday = DateTime(2026, 11, 30);

  group('Rechnen', () {
    const workdays = Habit(id: 'w', name: 'Laufen', weekdays: {1, 2, 3, 4, 5});
    const daily = Habit(id: 'd', name: 'Lesen');

    test('fällig je Wochentag', () {
      expect(workdays.isDueOn(friday), isTrue);
      expect(workdays.isDueOn(saturday), isFalse);
      expect(daily.isDueOn(saturday), isTrue);
      expect(workdays.scheduleText, 'Mo, Di, Mi, Do, Fr');
    });

    test('Wochenende unterbricht die Serie eines Werktags-Habits nicht', () {
      final done = days([DateTime(2026, 11, 26), friday, monday]);
      expect(habitStreak(workdays, done, monday), 3);
      expect(habitStreak(workdays, done, saturday), 2);
    });

    test('heute noch offen: Serie zählt bis gestern', () {
      final done = days([DateTime(2026, 11, 25), DateTime(2026, 11, 26)]);
      expect(habitStreak(daily, done, friday), 2);
      expect(habitStreak(daily, {...done, isoDate(friday)}, friday), 3);
      expect(habitStreak(daily, const {}, friday), 0);
    });

    test('Erfüllung der letzten 30 Tage', () {
      final done = {
        for (var i = 1; i <= 15; i++) isoDate(DateTime(friday.year, friday.month, friday.day - i)),
      };
      // 29 fällige Tage (heute offen, zählt nicht), 15 erledigt.
      expect(completionRate(daily, done, friday), closeTo(15 / 29, 0.0001));
      expect(completionRate(daily, const {}, friday), 0);
    });
  });

  group('Speichern', () {
    late LifeosDatabase dbA;
    late LifeosDatabase dbB;
    late HabitRepository repoA;
    late HabitRepository repoB;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      dbA = LifeosDatabase(NativeDatabase.memory());
      dbB = LifeosDatabase(NativeDatabase.memory());
      final recorderA = await ChangeRecorder.open(dbA);
      final recorderB = await ChangeRecorder.open(dbB);
      repoA = HabitRepository(dbA, recorderA);
      repoB = HabitRepository(dbB, recorderB);
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

    test('Abhaken und Zurücknehmen kommt auf dem anderen Gerät an', () async {
      final id = await repoA.create('Dehnen', weekdays: {1, 3, 5});
      await repoA.setDone(id, friday, true);
      await exchange();
      expect((await repoB.watchHabits().first).single.weekdays, {1, 3, 5});
      expect((await repoB.watchChecks(from: friday).first).single.habitId, id);

      await repoB.setDone(id, friday, false);
      await exchange();
      expect(await repoA.watchChecks(from: friday).first, isEmpty);

      await repoA.setDone(id, friday, true);
      await exchange();
      expect(await repoB.watchChecks(from: friday).first, hasLength(1));
    });

    test('beide Geräte haken denselben Tag ab: ein Haken', () async {
      final id = await repoA.create('Lesen');
      await exchange();
      await repoA.setDone(id, friday, true);
      await repoB.setDone(id, friday, true);
      await exchange();
      expect(await repoA.watchChecks(from: friday).first, hasLength(1));
      expect(HabitRepository.checkId(id, friday), HabitRepository.checkId(id, DateTime(2026, 11, 27, 23)));
    });

    test('Archivieren blendet aus, Bearbeiten ändert den Rhythmus', () async {
      final id = await repoA.create('Meditieren');
      await repoA.update(id, weekdays: {6, 7});
      expect((await repoA.watchHabits().first).single.weekdays, {6, 7});
      await repoA.archive(id);
      expect(await repoA.watchHabits().first, isEmpty);
    });
  });

  testWidgets('Seite zeigt fällige und heute freie Habits', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        habitsProvider.overrideWith(
          (ref) => Stream.value(const [
            Habit(id: 'a', name: 'Lesen'),
            Habit(id: 'b', name: 'Laufen', weekdays: {1, 3}),
          ]),
        ),
        habitChecksProvider.overrideWith(
          (ref) => Stream.value([HabitCheck(habitId: 'a', date: friday, done: true)]),
        ),
      ],
      child: MaterialApp(
        theme: buildLifeosTheme(Brightness.light),
        home: HabitsPage(clock: () => friday),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 von 1 erledigt'), findsOneWidget);
    expect(find.text('Heute nicht dran'), findsOneWidget);
    expect(find.text('Laufen'), findsOneWidget);
  });
}
