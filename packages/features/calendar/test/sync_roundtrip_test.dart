import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

void main() {
  late LifeosDatabase dbA;
  late LifeosDatabase dbB;
  late EventRepository repoA;
  late EventRepository repoB;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUp(() async {
    dbA = LifeosDatabase(NativeDatabase.memory());
    dbB = LifeosDatabase(NativeDatabase.memory());
    final recorderA = await ChangeRecorder.open(dbA);
    final recorderB = await ChangeRecorder.open(dbB);
    repoA = EventRepository(dbA, recorderA);
    repoB = EventRepository(dbB, recorderB);
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

  test('Termine, Serien und Erinnerungen kommen auf dem anderen Gerät an', () async {
    final id = await repoA.create(
      EventDraft(
        title: 'Training',
        location: 'Halle',
        start: DateTime(2026, 6, 1, 18),
        end: DateTime(2026, 6, 1, 19, 30),
        recurrence: const Recurrence(freq: RecurrenceFreq.weekly, weekdays: {1, 4}),
        tagIds: const ['sport'],
        reminderMinutes: 30,
        reminderDevices: const ['handy'],
        projectId: 'marathon',
      ),
    );
    await exchange();
    await repoB.excludeOccurrence(id, '2026-06-04');
    await exchange();

    final onA = (await repoA.find(id))!;
    final onB = (await repoB.find(id))!;
    for (final event in [onA, onB]) {
      expect(event.title, 'Training');
      expect(event.location, 'Halle');
      expect(event.start, DateTime(2026, 6, 1, 18).toUtc());
      expect(event.recurrence, const Recurrence(freq: RecurrenceFreq.weekly, weekdays: {1, 4}));
      expect(event.tagIds, ['sport']);
      expect(event.reminderMinutes, 30);
      expect(event.reminderDevices, ['handy']);
      expect(event.exdates, {'2026-06-04'});
      expect(event.projectId, 'marathon');
    }

    await repoA.delete(id);
    await exchange();
    expect(await repoB.watchAll().first, isEmpty);
  });
}
