import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';

CalendarEvent timed(
  DateTime localStart, {
  Duration length = const Duration(hours: 1),
  Recurrence? recurrence,
  Set<String> exdates = const {},
}) {
  return CalendarEvent(
    id: 'e',
    title: 'Termin',
    start: localStart.toUtc(),
    end: localStart.add(length).toUtc(),
    recurrence: recurrence,
    exdates: exdates,
  );
}

List<String> keys(List<Occurrence> list) => [for (final o in list) o.dateKey];

void main() {
  test('Einzeltermin nur im Fenster', () {
    final event = timed(DateTime(2026, 5, 4, 10));
    expect(expandOccurrences(event, DateTime(2026, 5, 1), DateTime(2026, 6, 1)), hasLength(1));
    expect(expandOccurrences(event, DateTime(2026, 6, 1), DateTime(2026, 7, 1)), isEmpty);
  });

  test('täglich alle 2 Tage', () {
    final event = timed(
      DateTime(2026, 5, 1, 7),
      recurrence: const Recurrence(freq: RecurrenceFreq.daily, interval: 2),
    );
    final list = expandOccurrences(event, DateTime(2026, 5, 1), DateTime(2026, 5, 8));
    expect(keys(list), ['2026-05-01', '2026-05-03', '2026-05-05', '2026-05-07']);
  });

  test('wöchentlich Montag und Mittwoch', () {
    // 04.05.2026 ist ein Montag.
    final event = timed(
      DateTime(2026, 5, 4, 18),
      recurrence: const Recurrence(freq: RecurrenceFreq.weekly, weekdays: {1, 3}),
    );
    final list = expandOccurrences(event, DateTime(2026, 5, 1), DateTime(2026, 5, 15));
    expect(keys(list), ['2026-05-04', '2026-05-06', '2026-05-11', '2026-05-13']);
  });

  test('monatlich am 31. lässt kurze Monate aus', () {
    final event = timed(
      DateTime(2026, 3, 31, 9),
      recurrence: const Recurrence(freq: RecurrenceFreq.monthly),
    );
    final list = expandOccurrences(event, DateTime(2026, 3, 1), DateTime(2026, 9, 1));
    expect(keys(list), ['2026-03-31', '2026-05-31', '2026-07-31', '2026-08-31']);
  });

  test('jährlich am 29.02. nur in Schaltjahren', () {
    final event = timed(
      DateTime(2024, 2, 29, 12),
      recurrence: const Recurrence(freq: RecurrenceFreq.yearly),
    );
    final list = expandOccurrences(event, DateTime(2024, 1, 1), DateTime(2033, 1, 1));
    expect(keys(list), ['2024-02-29', '2028-02-29', '2032-02-29']);
  });

  test('Enddatum ist inklusive und Ausnahmen fallen weg', () {
    final event = timed(
      DateTime(2026, 5, 1, 8),
      recurrence: Recurrence(freq: RecurrenceFreq.daily, until: DateTime(2026, 5, 4)),
      exdates: {'2026-05-02'},
    );
    final list = expandOccurrences(event, DateTime(2026, 4, 1), DateTime(2026, 6, 1));
    expect(keys(list), ['2026-05-01', '2026-05-03', '2026-05-04']);
  });

  test('Serie bleibt über die Zeitumstellung bei derselben Uhrzeit', () {
    final event = timed(
      DateTime(2026, 3, 16, 18),
      recurrence: const Recurrence(freq: RecurrenceFreq.weekly),
    );
    final list = expandOccurrences(event, DateTime(2026, 3, 1), DateTime(2026, 4, 30));
    expect(list, hasLength(7));
    for (final occurrence in list) {
      expect(occurrence.start.hour, 18, reason: occurrence.dateKey);
      expect(occurrence.end.difference(occurrence.start), const Duration(hours: 1));
    }
  });

  test('ganztägiger Termin bleibt am selben Kalendertag', () {
    final event = CalendarEvent(
      id: 'feiertag',
      title: 'Feiertag',
      allDay: true,
      start: DateTime.utc(2026, 5, 1),
      end: DateTime.utc(2026, 5, 2),
    );
    final list = expandOccurrences(event, DateTime(2026, 4, 1), DateTime(2026, 6, 1));
    expect(keys(list), ['2026-05-01']);
    expect(list.single.start, DateTime(2026, 5, 1));
    expect(list.single.end, DateTime(2026, 5, 2));
    expect(list.single.coversDay(DateTime(2026, 5, 1)), isTrue);
    expect(list.single.coversDay(DateTime(2026, 5, 2)), isFalse);
  });

  test('Fenster weit nach dem Serienstart liefert trotzdem Treffer', () {
    final event = timed(
      DateTime(2000, 1, 3, 6),
      recurrence: const Recurrence(freq: RecurrenceFreq.daily),
    );
    final list = expandOccurrences(event, DateTime(2026, 5, 1), DateTime(2026, 5, 3));
    expect(keys(list), ['2026-05-01', '2026-05-02']);
  });

  test('Wiederholungsregel übersteht JSON', () {
    final rule = Recurrence(
      freq: RecurrenceFreq.weekly,
      interval: 2,
      weekdays: const {5, 1},
      until: DateTime(2026, 12, 31),
    );
    expect(Recurrence.fromJson(rule.toJson()), rule);
    expect(Recurrence.fromJson({'freq': 'stündlich'}), isNull);
    expect(rule.describe(), 'Alle 2 Wochen bis 31.12.2026');
  });

  test('Verschieben eines Vorkommens verschiebt die Serie samt Wochentagen', () {
    // Serie Mo+Mi 18:00 ab Montag, 01.06.2026.
    final series = timed(
      DateTime(2026, 6, 1, 18),
      recurrence: const Recurrence(freq: RecurrenceFreq.weekly, weekdays: {1, 3}),
    );
    final occurrenceStart = DateTime(2026, 6, 8, 18);
    final edited = EventDraft.fromEvent(series, occurrenceStart: occurrenceStart)
        .copyWith(start: DateTime(2026, 6, 9, 19), end: DateTime(2026, 6, 9, 20));
    final result = applyToSeries(series: series, occurrenceStart: occurrenceStart, edited: edited);
    expect(result.start, DateTime(2026, 6, 2, 19));
    expect(result.end, DateTime(2026, 6, 2, 20));
    expect(result.recurrence!.weekdays, {2, 4});
  });
}

