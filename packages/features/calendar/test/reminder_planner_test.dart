import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';

CalendarEvent event(
  String id,
  DateTime localStart, {
  int? reminder = 15,
  List<String> devices = const [allDevices],
  bool allDay = false,
  Recurrence? recurrence,
}) {
  return CalendarEvent(
    id: id,
    title: 'Termin $id',
    allDay: allDay,
    start: allDay
        ? DateTime.utc(localStart.year, localStart.month, localStart.day)
        : localStart.toUtc(),
    end: allDay
        ? DateTime.utc(localStart.year, localStart.month, localStart.day + 1)
        : localStart.add(const Duration(hours: 1)).toUtc(),
    reminderMinutes: reminder,
    reminderDevices: devices,
    recurrence: recurrence,
  );
}

void main() {
  final now = DateTime(2026, 6, 1, 8);

  test('nur Termine für dieses Gerät oder alle Geräte', () {
    final plan = planReminders(
      events: [
        event('alle', DateTime(2026, 6, 1, 10)),
        event('pc', DateTime(2026, 6, 1, 11), devices: ['pc-id']),
        event('handy', DateTime(2026, 6, 1, 12), devices: ['handy-id']),
        event('ohne', DateTime(2026, 6, 1, 13), reminder: null),
      ],
      deviceId: 'handy-id',
      now: now,
    );
    expect([for (final r in plan) r.eventId], ['alle', 'handy']);
    expect(plan.first.fireAt, DateTime(2026, 6, 1, 9, 45).toUtc());
  });

  test('keine Erinnerungen in der Vergangenheit', () {
    final plan = planReminders(
      events: [event('vorbei', DateTime(2026, 6, 1, 8, 10))],
      deviceId: 'x',
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('höchstens 50, die frühesten zuerst', () {
    final plan = planReminders(
      events: [
        event(
          'täglich',
          DateTime(2026, 6, 1, 20),
          recurrence: const Recurrence(freq: RecurrenceFreq.daily),
        ),
        event(
          'zweimal',
          DateTime(2026, 6, 1, 7),
          recurrence: const Recurrence(freq: RecurrenceFreq.daily),
        ),
      ],
      deviceId: 'x',
      now: now,
    );
    expect(plan, hasLength(50));
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].fireAt.isBefore(plan[i - 1].fireAt), isFalse);
    }
    expect(plan.first.eventId, 'täglich');
  });

  test('ganztägig erinnert ausgehend von 9 Uhr', () {
    final plan = planReminders(
      events: [event('frei', DateTime(2026, 6, 3), allDay: true, reminder: 1440)],
      deviceId: 'x',
      now: now,
    );
    expect(plan.single.fireAt, DateTime(2026, 6, 2, 9).toUtc());
  });

  test('dieselbe Nummer für dasselbe Vorkommen', () {
    final a = reminderNotificationId('id-1', '2026-06-01');
    expect(reminderNotificationId('id-1', '2026-06-01'), a);
    expect(reminderNotificationId('id-1', '2026-06-02'), isNot(a));
    expect(a >= 0 && a <= 0x7fffffff, isTrue);
  });

  test('Texte für die Vorlaufzeit', () {
    expect(describeReminder(null), 'Keine Erinnerung');
    expect(describeReminder(0), 'Zum Beginn');
    expect(describeReminder(15), '15 Minuten vorher');
    expect(describeReminder(1440), '1 Tag vorher');
  });
}
