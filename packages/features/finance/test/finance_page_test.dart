import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

void main() {
  Widget host(List<FinanceEntry> entries, {List<TagItem> tags = const []}) => ProviderScope(
        overrides: [
          financeEntriesProvider.overrideWith((ref) => Stream.value(entries)),
          recurringRulesProvider.overrideWith((ref) => Stream.value(const [])),
          savingGoalsProvider.overrideWith((ref) => Stream.value(const [])),
          tagsProvider.overrideWith((ref, scope) => Stream.value(tags)),
        ],
        child: MaterialApp(
          theme: buildLifeosTheme(Brightness.light),
          home: FinancePage(clock: () => DateTime(2026, 5, 20), bookDueRecurring: false),
        ),
      );

  testWidgets('leere Finanzen bieten das Startguthaben an', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.text('Startguthaben eintragen'), findsOneWidget);
  });

  testWidgets('Übersicht zeigt Kontostand und Budget', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entries = [
      FinanceEntry(id: 'a', kind: EntryKind.income, amountCents: 250000, date: DateTime(2026, 5, 1)),
      FinanceEntry(
        id: 'b',
        kind: EntryKind.expense,
        amountCents: 4550,
        date: DateTime(2026, 5, 3),
        tagIds: const ['essen'],
      ),
    ];
    const essen = TagItem(id: 'essen', scope: TagScope.finance, name: 'Essen', monthlyLimitCents: 20000);
    await tester.pumpWidget(host(entries, tags: const [essen]));
    await tester.pumpAndSettle();
    expect(find.text(formatCents(245450)), findsOneWidget);
    expect(find.text('noch ${formatCents(15450)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
