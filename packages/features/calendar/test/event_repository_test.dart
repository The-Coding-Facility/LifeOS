import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

void main() {
  late LifeosDatabase db;
  late EventRepository repository;

  setUp(() async {
    db = LifeosDatabase(NativeDatabase.memory());
    repository = EventRepository(db, await ChangeRecorder.open(db));
  });

  tearDown(() => db.close());

  Future<List<ChangeLogEntry>> log() {
    final query = db.select(db.changeLog)..orderBy([(entry) => OrderingTerm.asc(entry.seq)]);
    return query.get();
  }

  EventDraft draft({String title = 'Zahnarzt', Recurrence? recurrence}) => EventDraft(
        title: title,
        start: DateTime(2026, 6, 1, 10),
        end: DateTime(2026, 6, 1, 11),
        recurrence: recurrence,
      );

  test('Anlegen speichert alle Werte in UTC', () async {
    final id = await repository.create(draft());
    final event = (await repository.watchAll().first).single;
    expect(event.id, id);
    expect(event.title, 'Zahnarzt');
    expect(event.start, DateTime(2026, 6, 1, 10).toUtc());
    expect(event.start.isUtc, isTrue);
    expect(event.reminderDevices, [allDevices]);
  });

  test('Bearbeiten protokolliert nur geänderte Feldgruppen', () async {
    final id = await repository.create(draft());
    final event = (await repository.watchAll().first).single;
    final changed = EventDraft.fromEvent(event).copyWith(title: 'Zahnarzt Dr. Weiß');
    await repository.update(id, changed);

    final last = (await log()).last;
    final payload = jsonDecode(last.payload) as Map<String, dynamic>;
    expect(payload.keys, ['title']);
    expect((await repository.find(id))!.title, 'Zahnarzt Dr. Weiß');

    final before = (await log()).length;
    await repository.update(id, changed);
    expect((await log()).length, before, reason: 'unveränderte Werte erzeugen nichts');
  });

  test('Verschieben behält die Dauer', () async {
    final id = await repository.create(draft());
    await repository.move(id, DateTime(2026, 6, 3, 14, 15));
    final event = (await repository.find(id))!;
    expect(event.start.toLocal(), DateTime(2026, 6, 3, 14, 15));
    expect(event.duration, const Duration(hours: 1));
  });

  test('einzelnes Vorkommen ändern trennt es von der Serie', () async {
    final seriesId = await repository.create(
      draft(recurrence: const Recurrence(freq: RecurrenceFreq.weekly)),
    );
    final series = (await repository.find(seriesId))!;
    final single = EventDraft.fromEvent(series, occurrenceStart: DateTime(2026, 6, 8, 10))
        .copyWith(title: 'Zahnarzt verschoben', start: DateTime(2026, 6, 9, 10), end: DateTime(2026, 6, 9, 11));
    final singleId = await repository.detachOccurrence(seriesId, '2026-06-08', single);

    final events = await repository.watchAll().first;
    expect(events, hasLength(2));
    expect((await repository.find(seriesId))!.exdates, {'2026-06-08'});
    final detached = (await repository.find(singleId))!;
    expect(detached.isRecurring, isFalse);
    expect(detached.start.toLocal(), DateTime(2026, 6, 9, 10));

    final june = expandAll(events, DateTime(2026, 6, 1), DateTime(2026, 6, 16));
    expect([for (final o in june) '${o.dateKey} ${o.event.title}'], [
      '2026-06-01 Zahnarzt',
      '2026-06-09 Zahnarzt verschoben',
      '2026-06-15 Zahnarzt',
    ]);
  });

  test('Löschen hinterlässt einen Tombstone', () async {
    final id = await repository.create(draft());
    await repository.delete(id);
    expect(await repository.watchAll().first, isEmpty);
    final row = await (db.select(db.calendarEvents)..where((e) => e.id.equals(id))).getSingle();
    expect(row.deletedHlc, isNotNull);
    expect((await log()).last.op, 'delete');
  });

  test('ganztägiger Termin über mehrere Tage', () async {
    final id = await repository.create(
      EventDraft(
        title: 'Urlaub',
        allDay: true,
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 12),
      ),
    );
    final event = (await repository.find(id))!;
    expect(event.start, DateTime.utc(2026, 7, 10));
    expect(event.end, DateTime.utc(2026, 7, 13));
    final draftAgain = EventDraft.fromEvent(event);
    expect(draftAgain.start, DateTime(2026, 7, 10));
    expect(draftAgain.end, DateTime(2026, 7, 12));
  });

  test('leerer Titel wird abgelehnt', () {
    expect(() => repository.create(draft(title: '   ')), throwsArgumentError);
  });
}
