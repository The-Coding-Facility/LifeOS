import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

void main() {
  final events = [
    CalendarEvent(
      id: 'zahnarzt',
      title: 'Zahnarzt',
      start: DateTime(2026, 6, 12, 10).toUtc(),
      end: DateTime(2026, 6, 12, 11).toUtc(),
    ),
    CalendarEvent(
      id: 'laufen',
      title: 'Laufen',
      start: DateTime(2026, 6, 15, 18).toUtc(),
      end: DateTime(2026, 6, 15, 19).toUtc(),
      tagIds: const ['sport'],
    ),
  ];
  const sport = TagItem(id: 'sport', scope: TagScope.calendar, name: 'Sport', colorIndex: 1);

  Widget host() => ProviderScope(
        overrides: [
          eventsProvider.overrideWith((ref) => Stream.value(events)),
          tagsProvider.overrideWith((ref, scope) => Stream.value(const [sport])),
        ],
        child: MaterialApp(
          theme: buildLifeosTheme(Brightness.light),
          home: CalendarPage(clock: () => DateTime(2026, 6, 10, 8)),
        ),
      );

  testWidgets('Monatsansicht zeigt Termine, Tag-Filter blendet aus', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Juni 2026'), findsOneWidget);
    expect(find.text('10:00 Zahnarzt'), findsOneWidget);
    expect(find.text('18:00 Laufen'), findsOneWidget);

    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();
    expect(find.text('10:00 Zahnarzt'), findsNothing);
    expect(find.text('18:00 Laufen'), findsOneWidget);
  });

  testWidgets('Wochenansicht zeigt das Stundenraster', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(find.text('KW 24 · Jun 2026'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Kalenderwochen nach ISO', () {
    expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
    expect(isoWeekNumber(DateTime(2026, 6, 10)), 24);
    expect(isoWeekNumber(DateTime(2027, 1, 1)), 53);
  });
}
