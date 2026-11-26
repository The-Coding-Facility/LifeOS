import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildLifeosTheme(Brightness.light),
        home: Scaffold(body: SizedBox(width: 400, child: child)),
      );

  String euro(int cents) => '${cents ~/ 100} €';

  for (final count in [0, 1, 365]) {
    testWidgets('Liniendiagramm mit $count Werten', (tester) async {
      await tester.pumpWidget(host(LineChartView(
        values: [for (var i = 0; i < count; i++) (i * 37) % 500 - 100],
        formatValue: euro,
        startLabel: 'vor 30 Tagen',
        endLabel: 'heute',
      )));
      expect(tester.takeException(), isNull);
      if (count == 0) expect(find.text('Noch keine Daten'), findsOneWidget);
    });
  }

  testWidgets('Balkendiagramm und Budgetbalken bauen ohne Fehler', (tester) async {
    await tester.pumpWidget(host(Column(children: [
      BarChartView(
        groups: [
          for (var m = 1; m <= 12; m++)
            BarGroup(label: '$m', values: [
              BarValue(m * 1000, Colors.green),
              BarValue(m * 800, Colors.red),
            ]),
        ],
        formatValue: euro,
      ),
      const BudgetBar(value: 12000, limit: 10000),
      const BudgetBar(value: 0, limit: 0),
    ])));
    expect(tester.takeException(), isNull);
  });

  test('Tag-Farben laufen im Kreis', () {
    expect(tagColor(tagPaletteSize), tagColor(0));
    expect(tagColor(3), isNot(tagColor(4)));
  });

  testWidgets('Tab-Leiste zeigt bei sechs Bereichen vier plus Mehr', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var selected = -1;
    final destinations = [
      for (final name in ['Übersicht', 'Kalender', 'Aufgaben', 'Finanzen', 'Notizen', 'Einstellungen'])
        ShellDestination(label: name, icon: Icons.circle_outlined, selectedIcon: Icons.circle),
    ];
    await tester.pumpWidget(MaterialApp(
      home: AdaptiveShell(
        destinations: destinations,
        selectedIndex: 0,
        onSelected: (index) => selected = index,
        body: const SizedBox(),
      ),
    ));
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Notizen'), findsNothing);
    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notizen'));
    await tester.pumpAndSettle();
    expect(selected, 4);
  });
}
