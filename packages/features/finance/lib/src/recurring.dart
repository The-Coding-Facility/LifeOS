import 'dart:math' as math;

import 'package:lifeos_core/lifeos_core.dart';

import 'model.dart';

/// Alle Buchungstage von [rule] vom Start bis einschließlich [today] (bzw.
/// bis zum Enddatum, wenn es früher liegt), ältester zuerst.
///
/// Monatlich und jährlich: Gibt es den Tag im Monat nicht (31., 29.02.),
/// wird am letzten Tag des Monats gebucht. Miete am 31. fällt also nicht aus.
List<DateTime> dueDates(RecurringRule rule, {required DateTime today}) {
  final start = dateOnly(rule.startDate);
  var last = dateOnly(today);
  final end = rule.endDate;
  if (end != null && dateOnly(end).isBefore(last)) last = dateOnly(end);
  if (start.isAfter(last)) return const [];

  final interval = math.max(1, rule.interval);
  final dates = <DateTime>[];
  for (var k = 0; k < 10000; k++) {
    final date = switch (rule.freq) {
      RecurringFreq.weekly => DateTime(start.year, start.month, start.day + 7 * interval * k),
      RecurringFreq.monthly => _clampedDay(start.year, start.month + interval * k, start.day),
      RecurringFreq.yearly => _clampedDay(start.year + interval * k, start.month, start.day),
    };
    if (date.isAfter(last)) break;
    dates.add(date);
  }
  return dates;
}

/// ID der Buchung, die [ruleId] am Tag [date] erzeugt. Auf jedem Gerät
/// gleich, damit dieselbe Buchung nie doppelt entsteht.
String recurringEntryId(String ruleId, DateTime date) =>
    Ids.deterministic('finance_recurring', '$ruleId|${isoDate(date)}');

DateTime _clampedDay(int year, int month, int day) {
  final firstOfMonth = DateTime(year, month);
  final daysInMonth = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
  return DateTime(firstOfMonth.year, firstOfMonth.month, math.min(day, daysInMonth));
}
