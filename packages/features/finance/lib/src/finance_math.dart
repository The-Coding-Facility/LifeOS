import 'dart:math' as math;

import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import 'model.dart';

/// Wirkung einer Buchung auf den Kontostand: Einnahmen und Entnahmen aus
/// Sparzielen erhöhen ihn, Ausgaben und Einzahlungen auf Sparziele senken ihn.
int signedCents(FinanceEntry entry) => switch (entry.kind) {
      EntryKind.income || EntryKind.withdrawal => entry.amountCents,
      EntryKind.expense || EntryKind.saving => -entry.amountCents,
    };

/// Kontostand am Ende von [upTo] (ohne Angabe: alle Buchungen).
int balance(Iterable<FinanceEntry> entries, {DateTime? upTo}) {
  final limit = upTo == null ? null : dateOnly(upTo);
  var sum = 0;
  for (final entry in entries) {
    if (limit != null && entry.date.isAfter(limit)) continue;
    sum += signedCents(entry);
  }
  return sum;
}

/// Kontostand am Ende jedes der letzten [days] Tage bis einschließlich
/// [today], ältester zuerst.
List<int> balanceSeries(Iterable<FinanceEntry> entries, {required DateTime today, required int days}) {
  if (days <= 0) return const [];
  final end = dateOnly(today);
  final first = DateTime(end.year, end.month, end.day - (days - 1));
  final daily = <String, int>{};
  var before = 0;
  for (final entry in entries) {
    if (entry.date.isBefore(first)) {
      before += signedCents(entry);
    } else if (!entry.date.isAfter(end)) {
      final key = isoDate(entry.date);
      daily[key] = (daily[key] ?? 0) + signedCents(entry);
    }
  }
  final series = <int>[];
  var running = before;
  for (var i = 0; i < days; i++) {
    final day = DateTime(first.year, first.month, first.day + i);
    running += daily[isoDate(day)] ?? 0;
    series.add(running);
  }
  return series;
}

/// Einnahmen und Ausgaben eines Monats.
class MonthTotals {
  const MonthTotals({required this.month, required this.incomeCents, required this.expenseCents});

  /// Erster Tag des Monats.
  final DateTime month;
  final int incomeCents;
  final int expenseCents;
}

/// Die letzten [months] Monate bis einschließlich des Monats von [today],
/// ältester zuerst. Sparziel-Buchungen zählen weder als Einnahme noch als
/// Ausgabe.
List<MonthTotals> monthTotals(
  Iterable<FinanceEntry> entries, {
  required DateTime today,
  int months = 12,
}) {
  final income = <String, int>{};
  final expense = <String, int>{};
  for (final entry in entries) {
    final key = _monthKey(entry.date);
    switch (entry.kind) {
      case EntryKind.income:
        income[key] = (income[key] ?? 0) + entry.amountCents;
      case EntryKind.expense:
        expense[key] = (expense[key] ?? 0) + entry.amountCents;
      case EntryKind.saving || EntryKind.withdrawal:
        break;
    }
  }
  final result = <MonthTotals>[];
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(today.year, today.month - i);
    final key = _monthKey(month);
    result.add(MonthTotals(month: month, incomeCents: income[key] ?? 0, expenseCents: expense[key] ?? 0));
  }
  return result;
}

/// Stand eines Budgets im laufenden Monat.
class BudgetStatus {
  const BudgetStatus({
    required this.tag,
    required this.limitCents,
    required this.spentCents,
    required this.lastMonthCents,
    required this.deltaCents,
  });

  final TagItem tag;
  final int limitCents;

  /// Ausgaben mit diesem Tag im laufenden Monat.
  final int spentCents;

  /// Ausgaben im Vormonat bis zum selben Tag des Monats.
  final int lastMonthCents;

  /// Ausgaben dieses Monats bis heute minus [lastMonthCents]. Negativ heißt:
  /// weniger ausgegeben als im Vormonat.
  final int deltaCents;

  int get remainingCents => limitCents - spentCents;

  double get ratio => limitCents <= 0 ? 0 : spentCents / limitCents;
}

/// Ausgaben mit dem Tag [tagId] im Monat von [month], bis einschließlich
/// Tag [untilDay] (ohne Angabe: ganzer Monat).
int spentInMonth(Iterable<FinanceEntry> entries, String tagId, DateTime month, {int? untilDay}) {
  var sum = 0;
  for (final entry in entries) {
    if (entry.kind != EntryKind.expense) continue;
    if (entry.date.year != month.year || entry.date.month != month.month) continue;
    if (untilDay != null && entry.date.day > untilDay) continue;
    if (!entry.tagIds.contains(tagId)) continue;
    sum += entry.amountCents;
  }
  return sum;
}

/// Budget von [tag] im Monat von [today]. Eine Buchung mit mehreren Tags
/// zählt in jedem davon voll.
BudgetStatus budgetFor(TagItem tag, Iterable<FinanceEntry> entries, DateTime today) {
  final thisMonth = DateTime(today.year, today.month);
  final lastMonth = DateTime(today.year, today.month - 1);
  final lastMonthDays = DateTime(today.year, today.month, 0).day;
  final compareDay = math.min(today.day, lastMonthDays);
  final spent = spentInMonth(entries, tag.id, thisMonth);
  final spentToDate = spentInMonth(entries, tag.id, thisMonth, untilDay: today.day);
  final last = spentInMonth(entries, tag.id, lastMonth, untilDay: compareDay);
  return BudgetStatus(
    tag: tag,
    limitCents: tag.monthlyLimitCents ?? 0,
    spentCents: spent,
    lastMonthCents: last,
    deltaCents: spentToDate - last,
  );
}

/// Auf dem Sparziel [goalId] liegender Betrag.
int savedFor(String goalId, Iterable<FinanceEntry> entries) {
  var sum = 0;
  for (final entry in entries) {
    if (entry.savingGoalId != goalId) continue;
    if (entry.kind == EntryKind.saving) sum += entry.amountCents;
    if (entry.kind == EntryKind.withdrawal) sum -= entry.amountCents;
  }
  return sum;
}

/// Ausgaben eines Monats für die Jahresliste.
class MonthGroup {
  const MonthGroup({required this.month, required this.entries, required this.totalCents});

  final DateTime month;
  final List<FinanceEntry> entries;
  final int totalCents;
}

/// Alle Ausgaben des Jahres [year], nach Monat gruppiert (Januar zuerst,
/// nur Monate mit Ausgaben), innerhalb des Monats nach Datum.
List<MonthGroup> yearExpenses(Iterable<FinanceEntry> entries, int year) {
  final byMonth = <int, List<FinanceEntry>>{};
  for (final entry in entries) {
    if (entry.kind != EntryKind.expense || entry.date.year != year) continue;
    byMonth.putIfAbsent(entry.date.month, () => []).add(entry);
  }
  final months = byMonth.keys.toList()..sort();
  return [
    for (final month in months)
      MonthGroup(
        month: DateTime(year, month),
        entries: byMonth[month]!..sort((a, b) => a.date.compareTo(b.date)),
        totalCents: byMonth[month]!.fold(0, (sum, entry) => sum + entry.amountCents),
      ),
  ];
}

String _monthKey(DateTime date) => '${date.year}-${date.month}';
