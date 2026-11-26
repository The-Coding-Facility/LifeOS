import 'package:lifeos_core/lifeos_core.dart';

import 'model/event.dart';
import 'model/recurrence.dart';

/// Ein konkretes Vorkommen eines Termins, in Ortszeit.
class Occurrence {
  const Occurrence({required this.event, required this.start, required this.end});

  final CalendarEvent event;

  /// Beginn und Ende in Ortszeit. Ganztägig: Mitternacht des ersten Tags
  /// und Mitternacht nach dem letzten Tag.
  final DateTime start;
  final DateTime end;

  bool get allDay => event.allDay;

  /// Schlüssel des Vorkommens innerhalb seiner Serie (`yyyy-mm-dd`).
  String get dateKey => isoDate(start);

  /// Liegt das Vorkommen (teilweise) am Tag [day]?
  bool coversDay(DateTime day) {
    final dayStart = dateOnly(day);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    return _overlaps(start, end, dayStart, dayEnd);
  }

  @override
  bool operator ==(Object other) =>
      other is Occurrence && other.event.id == event.id && other.start == start;

  @override
  int get hashCode => Object.hash(event.id, start);
}

/// Höchstzahl an Vorkommen je Aufruf, als Schutz vor Endlosschleifen.
const int maxOccurrencesPerCall = 1000;

/// Alle Vorkommen von [event], die das Fenster [from]–[to] (Ortszeit,
/// Ende exklusiv) berühren, nach Beginn sortiert.
///
/// Serien laufen in Ortszeit weiter: Ein Termin um 18:00 bleibt auch nach
/// der Zeitumstellung um 18:00. Monatlich am 31. und jährlich am 29.02.
/// fallen in Monaten bzw. Jahren ohne diesen Tag aus.
List<Occurrence> expandOccurrences(CalendarEvent event, DateTime from, DateTime to) {
  final base = _localStart(event);
  final allDayLength = _allDayLength(event);
  final duration = event.duration;

  DateTime endOf(DateTime start) => event.allDay
      ? DateTime(start.year, start.month, start.day + allDayLength)
      : start.add(duration);

  final recurrence = event.recurrence;
  if (recurrence == null) {
    final end = endOf(base);
    return _overlaps(base, end, from, to)
        ? [Occurrence(event: event, start: base, end: end)]
        : const [];
  }

  final result = <Occurrence>[];
  void consider(DateTime start) {
    if (event.exdates.contains(isoDate(start))) return;
    final end = endOf(start);
    if (_overlaps(start, end, from, to)) {
      result.add(Occurrence(event: event, start: start, end: end));
    }
  }

  bool beyond(DateTime start) {
    if (!start.isBefore(to)) return true;
    final until = recurrence.until;
    return until != null && dateOnly(start).isAfter(dateOnly(until));
  }

  // Nicht ab Serienstart zählen, sondern kurz vor das Fenster springen.
  final lookback = from.subtract(
    (event.allDay ? Duration(days: allDayLength) : duration) + const Duration(days: 1),
  );
  final interval = recurrence.interval;
  var iterations = 0;

  switch (recurrence.freq) {
    case RecurrenceFreq.daily:
      final skip = _unitsBetween(base, lookback, days: 1) ~/ interval;
      for (var k = skip > 1 ? skip - 1 : 0; iterations++ < 5000; k++) {
        final start = _addDays(base, k * interval);
        if (beyond(start)) break;
        consider(start);
        if (result.length >= maxOccurrencesPerCall) break;
      }
    case RecurrenceFreq.weekly:
      final weekdays = recurrence.weekdays.isEmpty
          ? <int>[base.weekday]
          : (recurrence.weekdays.toList()..sort());
      final monday = _addDays(base, -(base.weekday - 1));
      final skip = _unitsBetween(base, lookback, days: 7) ~/ interval;
      var done = false;
      for (var w = skip > 1 ? skip - 1 : 0; !done && iterations++ < 5000; w++) {
        for (final weekday in weekdays) {
          final start = _addDays(monday, w * interval * 7 + weekday - 1);
          if (start.isBefore(base)) continue;
          if (beyond(start)) {
            done = true;
            break;
          }
          consider(start);
          if (result.length >= maxOccurrencesPerCall) {
            done = true;
            break;
          }
        }
      }
    case RecurrenceFreq.monthly:
      final months = (lookback.year - base.year) * 12 + lookback.month - base.month;
      final skip = months > 0 ? months ~/ interval : 0;
      for (var k = skip > 1 ? skip - 1 : 0; iterations++ < 5000; k++) {
        final start = DateTime(
          base.year,
          base.month + k * interval,
          base.day,
          base.hour,
          base.minute,
          base.second,
        );
        if (beyond(start)) break;
        if (start.day != base.day) continue;
        consider(start);
        if (result.length >= maxOccurrencesPerCall) break;
      }
    case RecurrenceFreq.yearly:
      final years = lookback.year - base.year;
      final skip = years > 0 ? years ~/ interval : 0;
      for (var k = skip > 1 ? skip - 1 : 0; iterations++ < 5000; k++) {
        final start = DateTime(
          base.year + k * interval,
          base.month,
          base.day,
          base.hour,
          base.minute,
          base.second,
        );
        if (beyond(start)) break;
        if (start.month != base.month || start.day != base.day) continue;
        consider(start);
        if (result.length >= maxOccurrencesPerCall) break;
      }
  }

  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

/// Vorkommen mehrerer Termine im Fenster, nach Beginn sortiert.
List<Occurrence> expandAll(Iterable<CalendarEvent> events, DateTime from, DateTime to) {
  final all = [for (final event in events) ...expandOccurrences(event, from, to)];
  all.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.event.title.compareTo(b.event.title);
  });
  return all;
}

DateTime _localStart(CalendarEvent event) => event.allDay
    ? DateTime(event.start.year, event.start.month, event.start.day)
    : event.start.toLocal();

int _allDayLength(CalendarEvent event) {
  final days = event.end.difference(event.start).inHours / 24;
  final rounded = days.round();
  return rounded < 1 ? 1 : rounded;
}

DateTime _addDays(DateTime base, int days) => DateTime(
      base.year,
      base.month,
      base.day + days,
      base.hour,
      base.minute,
      base.second,
    );

int _unitsBetween(DateTime base, DateTime target, {required int days}) {
  if (!target.isAfter(base)) return 0;
  return target.difference(base).inDays ~/ days;
}

bool _overlaps(DateTime start, DateTime end, DateTime from, DateTime to) {
  if (!start.isBefore(to)) return false;
  // Termine ohne Dauer zählen, wenn ihr Beginn im Fenster liegt.
  return end.isAfter(from) || !start.isBefore(from);
}
