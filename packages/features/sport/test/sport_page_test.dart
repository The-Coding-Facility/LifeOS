import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_sport/lifeos_sport.dart';

void main() {
  final today = DateTime(2026, 11, 28);

  List<Override> overrides() => [
        nutritionLogsProvider.overrideWith(
          (ref) => Stream.value([
            NutritionLog(id: '1', date: today, kcal: 1850),
            NutritionLog(id: '2', date: today, waterMl: 250),
          ]),
        ),
        sportGoalsProvider.overrideWith((ref) => Stream.value(const IntakeGoals(kcal: 2000, waterMl: 2500))),
        workoutSessionsProvider.overrideWith(
          (ref) => Stream.value([
            WorkoutSession(id: 'w', planId: 'p', startedAt: DateTime(2026, 11, 27, 18), duration: const Duration(minutes: 40)),
          ]),
        ),
        trainingPlansProvider.overrideWith(
          (ref) => Stream.value(const [
            TrainingPlan(id: 'p', name: 'Ganzkörper', steps: [PlanStep(exerciseId: 'e')]),
          ]),
        ),
        exercisesProvider.overrideWith((ref) => Stream.value(const [Exercise(id: 'e', name: 'Kniebeuge')])),
        bodyEntriesProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
        dailyReportsProvider.overrideWith((ref) => Stream.value(const <DailyReport>[])),
      ];

  testWidgets('Kachel zeigt Aufnahme gegen Ziel und letztes Training', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: MaterialApp(
        theme: buildLifeosTheme(Brightness.light),
        home: Scaffold(body: SportTile(onOpen: () {}, clock: () => today)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1850 / 2000'), findsOneWidget);
    expect(find.text('250 / 2500 ml'), findsOneWidget);
    expect(find.textContaining('Ganzkörper'), findsOneWidget);
  });

  testWidgets('Sportseite öffnet mit Übersicht und Plänen', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: MaterialApp(theme: buildLifeosTheme(Brightness.light), home: SportPage(clock: () => today)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Körperdaten'), findsOneWidget);
    await tester.tap(find.text('Pläne'));
    await tester.pumpAndSettle();
    expect(find.text('Ganzkörper'), findsWidgets);
    expect(find.textContaining('1 Übungen'), findsOneWidget);
  });

  test('Countdown-Format', () {
    expect(formatCountdown(const Duration(seconds: 65)), '1:05');
    expect(formatCountdown(Duration.zero), '0:00');
  });
}
