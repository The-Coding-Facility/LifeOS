import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_finance/lifeos_finance.dart';

RecurringRule rule(RecurringFreq freq, DateTime start, {int interval = 1, DateTime? end}) => RecurringRule(
      id: 'r',
      kind: EntryKind.expense,
      amountCents: 80000,
      freq: freq,
      startDate: start,
      interval: interval,
      endDate: end,
    );

void main() {
  test('monatlich am 31. bucht am Monatsletzten', () {
    final dates = dueDates(rule(RecurringFreq.monthly, DateTime(2026, 1, 31)), today: DateTime(2026, 5, 1));
    expect(dates, [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)]);
  });

  test('wöchentlich alle 2 Wochen bis zum Enddatum', () {
    final dates = dueDates(
      rule(RecurringFreq.weekly, DateTime(2026, 5, 1), interval: 2, end: DateTime(2026, 5, 29)),
      today: DateTime(2026, 12, 31),
    );
    expect(dates, [DateTime(2026, 5, 1), DateTime(2026, 5, 15), DateTime(2026, 5, 29)]);
  });

  test('jährlich am 29.02. bucht in anderen Jahren am 28.02.', () {
    final dates = dueDates(rule(RecurringFreq.yearly, DateTime(2024, 2, 29)), today: DateTime(2026, 3, 1));
    expect(dates, [DateTime(2024, 2, 29), DateTime(2025, 2, 28), DateTime(2026, 2, 28)]);
  });

  test('Start in der Zukunft bucht nichts', () {
    expect(dueDates(rule(RecurringFreq.monthly, DateTime(2027, 1, 1)), today: DateTime(2026, 5, 1)), isEmpty);
  });

  test('IDs sind je Auftrag und Tag gleich', () {
    final id = recurringEntryId('r', DateTime(2026, 5, 1));
    expect(recurringEntryId('r', DateTime(2026, 5, 1, 13)), id);
    expect(recurringEntryId('r', DateTime(2026, 6, 1)), isNot(id));
    expect(recurringEntryId('s', DateTime(2026, 5, 1)), isNot(id));
  });
}
