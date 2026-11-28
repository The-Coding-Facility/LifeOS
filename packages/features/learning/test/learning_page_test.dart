import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_learning/lifeos_learning.dart';

void main() {
  testWidgets('Liste zeigt Bereiche mit letzter Einheit', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learningAreasProvider.overrideWith(
          (ref) => Stream.value(const [LearningArea(id: 'a', name: 'Spanisch'), LearningArea(id: 'b', name: 'Erste Hilfe')]),
        ),
        studySessionsProvider.overrideWith(
          (ref) => Stream.value([
            StudySession(
              id: 's',
              areaId: 'a',
              mode: StudyMode.learn,
              startedAt: DateTime(2026, 11, 27, 18),
              duration: const Duration(minutes: 4),
              total: 10,
              correct: 7,
            ),
          ]),
        ),
      ],
      child: MaterialApp(theme: buildLifeosTheme(Brightness.light), home: const LearningPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Spanisch'), findsOneWidget);
    expect(find.text('1 Einheiten · zuletzt 27.11.2026 · 70 % richtig'), findsOneWidget);
    expect(find.text('Noch nicht gelernt'), findsOneWidget);
  });
}
