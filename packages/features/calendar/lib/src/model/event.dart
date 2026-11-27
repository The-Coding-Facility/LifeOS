import 'recurrence.dart';

/// Geräteauswahl „alle Geräte“ bei Erinnerungen.
const String allDevices = '*';

/// Ein gespeicherter Termin (bei Serien: die Regel mit dem ersten Termin).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.allDay = false,
    this.recurrence,
    this.exdates = const {},
    this.tagIds = const [],
    this.reminderMinutes,
    this.reminderDevices = const [allDevices],
    this.projectId,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;

  /// Ganztägig: [start] ist UTC-Mitternacht des ersten Tags, [end] die
  /// UTC-Mitternacht nach dem letzten Tag.
  final bool allDay;

  /// Beginn und Ende in UTC.
  final DateTime start;
  final DateTime end;

  final Recurrence? recurrence;

  /// Ausgelassene Vorkommen einer Serie, als `yyyy-mm-dd` ihres Beginns.
  final Set<String> exdates;
  final List<String> tagIds;

  /// Minuten vor Beginn, `null` = keine Erinnerung.
  final int? reminderMinutes;

  /// Geräte-IDs, auf denen die Erinnerung kommt. `*` = alle.
  final List<String> reminderDevices;

  /// Projekt, zu dem der Termin gehört.
  final String? projectId;

  bool get isRecurring => recurrence != null;

  Duration get duration => end.difference(start);

  /// Kommt die Erinnerung auf dem Gerät [deviceId]?
  bool remindsOn(String deviceId) =>
      reminderMinutes != null &&
      (reminderDevices.contains(allDevices) || reminderDevices.contains(deviceId));
}

/// Eingaben aus dem Formular, aus denen ein Termin wird.
///
/// [start] und [end] sind Ortszeit wie im Formular gewählt. Bei
/// ganztägigen Terminen zählen nur die Kalendertage; [end] ist dann der
/// letzte Tag (inklusive).
class EventDraft {
  const EventDraft({
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.allDay = false,
    this.recurrence,
    this.tagIds = const [],
    this.reminderMinutes,
    this.reminderDevices = const [allDevices],
    this.projectId,
  });

  /// Formularwerte aus einem bestehenden Termin bzw. einem Vorkommen.
  factory EventDraft.fromEvent(CalendarEvent event, {DateTime? occurrenceStart}) {
    final localStart = event.allDay
        ? DateTime(event.start.year, event.start.month, event.start.day)
        : event.start.toLocal();
    final start = occurrenceStart ?? localStart;
    final DateTime end;
    if (event.allDay) {
      final days = event.end.difference(event.start).inDays;
      end = DateTime(start.year, start.month, start.day + (days < 1 ? 0 : days - 1));
    } else {
      end = start.add(event.duration);
    }
    return EventDraft(
      title: event.title,
      description: event.description,
      location: event.location,
      allDay: event.allDay,
      start: start,
      end: end,
      recurrence: event.recurrence,
      tagIds: event.tagIds,
      reminderMinutes: event.reminderMinutes,
      reminderDevices: event.reminderDevices,
      projectId: event.projectId,
    );
  }

  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final Recurrence? recurrence;
  final List<String> tagIds;
  final int? reminderMinutes;
  final List<String> reminderDevices;
  final String? projectId;

  /// Beginn in UTC, wie gespeichert.
  DateTime get storedStart =>
      allDay ? DateTime.utc(start.year, start.month, start.day) : start.toUtc();

  /// Ende in UTC, wie gespeichert. Nie vor dem Beginn.
  DateTime get storedEnd {
    if (allDay) {
      final last = DateTime.utc(end.year, end.month, end.day);
      final first = storedStart;
      final exclusive = last.isBefore(first) ? first : last;
      return DateTime.utc(exclusive.year, exclusive.month, exclusive.day + 1);
    }
    final utcEnd = end.toUtc();
    return utcEnd.isBefore(storedStart) ? storedStart : utcEnd;
  }

  EventDraft copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    Recurrence? recurrence,
    bool clearRecurrence = false,
  }) {
    return EventDraft(
      title: title ?? this.title,
      description: description,
      location: location,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      tagIds: tagIds,
      reminderMinutes: reminderMinutes,
      reminderDevices: reminderDevices,
      projectId: projectId,
    );
  }
}
