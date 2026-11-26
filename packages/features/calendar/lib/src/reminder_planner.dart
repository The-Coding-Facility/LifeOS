import 'model/event.dart';
import 'occurrences.dart';

/// Eine Erinnerung, die dieses Gerät anzeigen soll.
class PlannedReminder {
  const PlannedReminder({
    required this.notificationId,
    required this.eventId,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  /// Stabile Nummer je Vorkommen (31 Bit), damit Neuplanen dieselbe
  /// Benachrichtigung ersetzt statt eine zweite anzulegen.
  final int notificationId;
  final String eventId;
  final String title;
  final String body;

  /// Zeitpunkt in UTC.
  final DateTime fireAt;

  @override
  String toString() => 'PlannedReminder($title @ $fireAt)';
}

/// Ganztägige Termine erinnern ausgehend von 9:00 Uhr am Tag selbst.
const int allDayReminderHour = 9;

/// Wählbare Vorlaufzeiten in Minuten (`0` = zum Beginn).
const List<int> reminderChoices = [0, 5, 10, 15, 30, 60, 1440];

/// Text für eine Vorlaufzeit, z. B. „15 Minuten vorher“.
String describeReminder(int? minutes) => switch (minutes) {
      null => 'Keine Erinnerung',
      0 => 'Zum Beginn',
      60 => '1 Stunde vorher',
      1440 => '1 Tag vorher',
      final int m when m % 1440 == 0 => '${m ~/ 1440} Tage vorher',
      final int m when m % 60 == 0 => '${m ~/ 60} Stunden vorher',
      final int m => '$m Minuten vorher',
    };

/// Berechnet die Erinnerungen der nächsten [window] für das Gerät
/// [deviceId]: nur Termine, deren Geräteauswahl `*` oder [deviceId]
/// enthält, nur zukünftige, höchstens [limit] Stück, früheste zuerst.
List<PlannedReminder> planReminders({
  required List<CalendarEvent> events,
  required String deviceId,
  required DateTime now,
  Duration window = const Duration(days: 30),
  int limit = 50,
}) {
  final localNow = now.toLocal();
  final horizon = localNow.add(window);
  final planned = <PlannedReminder>[];

  for (final event in events) {
    if (!event.remindsOn(deviceId)) continue;
    final minutes = event.reminderMinutes!;
    // Vorkommen dürfen bis zur Vorlaufzeit nach dem Horizont beginnen.
    final occurrences = expandOccurrences(
      event,
      localNow,
      horizon.add(Duration(minutes: minutes)),
    );
    for (final occurrence in occurrences) {
      final base = occurrence.allDay
          ? DateTime(
              occurrence.start.year,
              occurrence.start.month,
              occurrence.start.day,
              allDayReminderHour,
            )
          : occurrence.start;
      final fireAt = base.subtract(Duration(minutes: minutes));
      if (!fireAt.isAfter(localNow) || fireAt.isAfter(horizon)) continue;
      planned.add(
        PlannedReminder(
          notificationId: reminderNotificationId(event.id, occurrence.dateKey),
          eventId: event.id,
          title: event.title,
          body: _body(occurrence),
          fireAt: fireAt.toUtc(),
        ),
      );
    }
  }

  planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return planned.length > limit ? planned.sublist(0, limit) : planned;
}

/// FNV-1a über Termin-ID und Datum, auf 31 Bit gekürzt.
int reminderNotificationId(String eventId, String dateKey) {
  var hash = 0x811c9dc5;
  for (final unit in '$eventId|$dateKey'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

String _body(Occurrence occurrence) {
  final start = occurrence.start;
  final date = '${start.day}.${start.month}.';
  final time = occurrence.allDay
      ? 'Ganztägig'
      : '${_two(start.hour)}:${_two(start.minute)}–${_two(occurrence.end.hour)}:${_two(occurrence.end.minute)}';
  final location = occurrence.event.location;
  return location == null ? '$date $time' : '$date $time · $location';
}

String _two(int value) => value.toString().padLeft(2, '0');
