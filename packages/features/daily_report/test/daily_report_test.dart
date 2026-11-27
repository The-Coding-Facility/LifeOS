import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

void main() {
  group('Rechnen', () {
    test('Uhrzeiten lesen und schreiben', () {
      expect(parseClock('23:30'), 1410);
      expect(parseClock('7:05'), 425);
      expect(parseClock('24:00'), isNull);
      expect(parseClock('abc'), isNull);
      expect(formatClock(425), '07:05');
    });

    test('Schlafdauer über Mitternacht', () {
      expect(sleepDuration(parseClock('23:30'), parseClock('07:00')), const Duration(hours: 7, minutes: 30));
      expect(sleepDuration(parseClock('01:00'), parseClock('09:00')), const Duration(hours: 8));
      expect(sleepDuration(null, parseClock('07:00')), isNull);
      expect(formatDuration(const Duration(hours: 7, minutes: 5)), '7:05 h');
    });

    test('Serie zählt bis gestern, wenn heute noch offen ist', () {
      final today = DateTime(2026, 11, 27);
      final dates = [DateTime(2026, 11, 26), DateTime(2026, 11, 25), DateTime(2026, 11, 23)];
      expect(reportStreak(dates, today), 2);
      expect(reportStreak([today, ...dates], today), 3);
      expect(reportStreak(const [], today), 0);
    });
  });

  group('Speichern', () {
    late LifeosDatabase dbA;
    late LifeosDatabase dbB;
    late DailyReportRepository repoA;
    late DailyReportRepository repoB;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      dbA = LifeosDatabase(NativeDatabase.memory());
      dbB = LifeosDatabase(NativeDatabase.memory());
      final recorderA = await ChangeRecorder.open(dbA);
      final recorderB = await ChangeRecorder.open(dbB);
      repoA = DailyReportRepository(dbA, recorderA);
      repoB = DailyReportRepository(dbB, recorderB);
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

    final day = DateTime(2026, 11, 27);

    test('zwei Geräte füllen denselben Tag aus und haben einen Bericht', () async {
      await repoA.save(DailyReport(date: day, successes: 'Projekt fertig', kcalGoalMet: true));
      await repoB.save(DailyReport(date: day, learned: 'Drift-Migrationen', sleptAt: 1410, wokeAt: 420));
      await exchange();

      final onA = await repoA.watchAll().first;
      final onB = await repoB.watchAll().first;
      expect(onA, hasLength(1));
      expect(onB, hasLength(1));
      expect(DailyReportRepository.idFor(day), DailyReportRepository.idFor(DateTime(2026, 11, 27, 22)));
      // Je Feldgruppe gewinnt dieselbe Version auf beiden Geräten.
      expect(onA.single.successes, onB.single.successes);
      expect(onA.single.learned, onB.single.learned);
      expect(onA.single.sleep, onB.single.sleep);
    });

    test('Bearbeiten protokolliert nur geänderte Feldgruppen', () async {
      await repoA.save(DailyReport(date: day, successes: 'A'));
      await repoA.save(DailyReport(date: day, successes: 'A', waterGoalMet: true));
      final log = await (dbA.select(dbA.changeLog)..orderBy([(e) => OrderingTerm.asc(e.seq)])).get();
      final payload = jsonDecode(log.last.payload) as Map<String, dynamic>;
      expect(payload.keys, ['checks']);
      expect((await repoA.find(day))!.waterGoalMet, isTrue);
    });

    test('gelöschter Bericht kann neu gespeichert werden', () async {
      await repoA.save(DailyReport(date: day, successes: 'A'));
      await repoA.delete(day);
      expect(await repoA.find(day), isNull);
      await repoA.save(DailyReport(date: day, successes: 'B'));
      expect((await repoA.find(day))!.successes, 'B');
    });
  });

  testWidgets('Seite zeigt die Felder und die Termine des Tages', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dailyReportsProvider.overrideWith((ref) => Stream.value(const [])),
        eventsProvider.overrideWith(
          (ref) => Stream.value([
            CalendarEvent(
              id: 'e',
              title: 'Zahnarzt',
              start: DateTime(2026, 11, 27, 10).toUtc(),
              end: DateTime(2026, 11, 27, 11).toUtc(),
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: buildLifeosTheme(Brightness.light),
        home: DailyReportPage(clock: () => DateTime(2026, 11, 27, 21)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Erfolge'), findsOneWidget);
    expect(find.text('Kalender abgearbeitet'), findsOneWidget);
    expect(find.text('10:00  Zahnarzt'), findsOneWidget);
    expect(find.text('Noch nicht ausgefüllt'), findsOneWidget);
  });
}
