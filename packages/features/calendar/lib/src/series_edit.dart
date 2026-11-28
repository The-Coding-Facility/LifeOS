import 'model/event.dart';
import 'model/recurrence.dart';

/// Abstand in Kalendertagen, unabhängig von der Zeitumstellung.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Überträgt die Änderung eines Vorkommens auf die ganze Serie.
///
/// [edited] sind die Formularwerte, ausgehend vom Vorkommen, das um
/// [occurrenceStart] beginnt. Wurde es um n Tage oder auf eine andere
/// Uhrzeit verschoben, verschiebt sich der Serienstart genauso. Bei
/// wöchentlichen Serien mit Wochentagen wandern die Wochentage mit.
EventDraft applyToSeries({
  required CalendarEvent series,
  required DateTime occurrenceStart,
  required EventDraft edited,
}) {
  final seriesStart = EventDraft.fromEvent(series).start;
  final dayShift = calendarDaysBetween(occurrenceStart, edited.start);
  final newStart = edited.allDay
      ? DateTime(seriesStart.year, seriesStart.month, seriesStart.day + dayShift)
      : DateTime(
          seriesStart.year,
          seriesStart.month,
          seriesStart.day + dayShift,
          edited.start.hour,
          edited.start.minute,
        );
  final DateTime newEnd;
  if (edited.allDay) {
    final days = calendarDaysBetween(edited.start, edited.end);
    newEnd = DateTime(newStart.year, newStart.month, newStart.day + (days < 0 ? 0 : days));
  } else {
    newEnd = newStart.add(edited.end.difference(edited.start));
  }

  var recurrence = edited.recurrence;
  if (recurrence != null &&
      recurrence.freq == RecurrenceFreq.weekly &&
      recurrence.weekdays.isNotEmpty &&
      dayShift % 7 != 0) {
    recurrence = recurrence.copyWith(
      weekdays: {for (final day in recurrence.weekdays) (day - 1 + dayShift) % 7 + 1},
    );
  }

  return EventDraft(
    title: edited.title,
    description: edited.description,
    location: edited.location,
    allDay: edited.allDay,
    start: newStart,
    end: newEnd,
    recurrence: recurrence,
    tagIds: edited.tagIds,
    reminderMinutes: edited.reminderMinutes,
    reminderDevices: edited.reminderDevices,
    projectId: edited.projectId,
    trainingPlanId: edited.trainingPlanId,
  );
}
