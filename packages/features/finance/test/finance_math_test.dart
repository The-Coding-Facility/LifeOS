import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

var _next = 0;

FinanceEntry entry(
  EntryKind kind,
  int cents,
  DateTime date, {
  List<String> tags = const [],
  String? goal,
}) =>
    FinanceEntry(
      id: 'e${_next++}',
      kind: kind,
      amountCents: cents,
      date: date,
      tagIds: tags,
      savingGoalId: goal,
    );

void main() {
  test('Kontostand mit allen vier Arten', () {
    final entries = [
      entry(EntryKind.income, 300000, DateTime(2026, 5, 1)),
      entry(EntryKind.expense, 10000, DateTime(2026, 5, 2)),
      entry(EntryKind.saving, 50000, DateTime(2026, 5, 3), goal: 'urlaub'),
      entry(EntryKind.withdrawal, 20000, DateTime(2026, 5, 4), goal: 'urlaub'),
    ];
    expect(balance(entries), 260000);
    expect(balance(entries, upTo: DateTime(2026, 5, 2)), 290000);
    expect(savedFor('urlaub', entries), 30000);
  });

  test('Verlauf über 30 Tage endet beim aktuellen Kontostand', () {
    final today = DateTime(2026, 5, 31);
    final entries = [
      entry(EntryKind.income, 100000, DateTime(2026, 4, 1)),
      entry(EntryKind.expense, 2500, DateTime(2026, 5, 10)),
      entry(EntryKind.expense, 500, DateTime(2026, 5, 31)),
    ];
    final series = balanceSeries(entries, today: today, days: 30);
    expect(series, hasLength(30));
    expect(series.first, 100000);
    expect(series.last, balance(entries));
    // Der Verlauf beginnt am 02.05.; Index 7 ist der 09.05., Index 8 der 10.05.
    expect(series[7], 100000, reason: '09.05. vor der Ausgabe');
    expect(series[8], 97500, reason: '10.05. nach der Ausgabe');
  });

  test('Monatssummen ohne Sparziel-Buchungen', () {
    final entries = [
      entry(EntryKind.income, 200000, DateTime(2026, 4, 1)),
      entry(EntryKind.expense, 5000, DateTime(2026, 4, 15)),
      entry(EntryKind.saving, 10000, DateTime(2026, 4, 16)),
      entry(EntryKind.expense, 7000, DateTime(2026, 5, 2)),
    ];
    final totals = monthTotals(entries, today: DateTime(2026, 5, 20), months: 3);
    expect([for (final t in totals) t.month], [DateTime(2026, 3), DateTime(2026, 4), DateTime(2026, 5)]);
    expect(totals[1].incomeCents, 200000);
    expect(totals[1].expenseCents, 5000);
    expect(totals[2].expenseCents, 7000);
  });

  test('Budget 100 € mit Einkauf 100 € hat 0 € übrig', () {
    const essen = TagItem(id: 'essen', scope: TagScope.finance, name: 'Essen', monthlyLimitCents: 10000);
    final status = budgetFor(
      essen,
      [entry(EntryKind.expense, 10000, DateTime(2026, 5, 3), tags: ['essen'])],
      DateTime(2026, 5, 20),
    );
    expect(status.spentCents, 10000);
    expect(status.remainingCents, 0);
    expect(status.ratio, 1);
  });

  test('Vergleich mit dem Vormonat bis zum selben Tag', () {
    const essen = TagItem(id: 'essen', scope: TagScope.finance, name: 'Essen', monthlyLimitCents: 30000);
    final entries = [
      entry(EntryKind.expense, 4000, DateTime(2026, 2, 10), tags: ['essen']),
      entry(EntryKind.expense, 3000, DateTime(2026, 2, 28), tags: ['essen']),
      entry(EntryKind.expense, 2000, DateTime(2026, 3, 5), tags: ['essen']),
      entry(EntryKind.expense, 9999, DateTime(2026, 3, 6), tags: ['anderes']),
    ];
    final status = budgetFor(essen, entries, DateTime(2026, 3, 31));
    expect(status.lastMonthCents, 7000, reason: 'Februar bis zum 28.');
    expect(status.deltaCents, -5000, reason: '50 € weniger als im Vormonat');

    final early = budgetFor(essen, entries, DateTime(2026, 3, 15));
    expect(early.lastMonthCents, 4000, reason: 'Februar nur bis zum 15.');
  });

  test('Buchung mit zwei Tags zählt in beiden Budgets', () {
    const a = TagItem(id: 'a', scope: TagScope.finance, name: 'A', monthlyLimitCents: 1000);
    const b = TagItem(id: 'b', scope: TagScope.finance, name: 'B', monthlyLimitCents: 1000);
    final entries = [entry(EntryKind.expense, 600, DateTime(2026, 5, 1), tags: ['a', 'b'])];
    expect(budgetFor(a, entries, DateTime(2026, 5, 2)).spentCents, 600);
    expect(budgetFor(b, entries, DateTime(2026, 5, 2)).spentCents, 600);
  });

  test('Jahresliste gruppiert Ausgaben nach Monat', () {
    final entries = [
      entry(EntryKind.expense, 100, DateTime(2026, 3, 9)),
      entry(EntryKind.expense, 200, DateTime(2026, 1, 2)),
      entry(EntryKind.expense, 300, DateTime(2026, 1, 1)),
      entry(EntryKind.income, 999, DateTime(2026, 1, 1)),
      entry(EntryKind.expense, 400, DateTime(2025, 12, 31)),
    ];
    final groups = yearExpenses(entries, 2026);
    expect([for (final g in groups) g.month.month], [1, 3]);
    expect(groups.first.totalCents, 500);
    expect(groups.first.entries.first.amountCents, 300);
  });
}
