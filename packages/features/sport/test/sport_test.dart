import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sport/lifeos_sport.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

void main() {
  final today = DateTime(2026, 11, 28);

  group('Rechnen', () {
    test('Tagessumme des Trackers', () {
      final logs = [
        NutritionLog(id: '1', date: today, kcal: 500, protein: 30, fat: 10),
        NutritionLog(id: '2', date: today, waterMl: 250),
        NutritionLog(id: '3', date: DateTime(2026, 11, 27), kcal: 900),
      ];
      final intake = intakeOn(logs, today);
      expect(intake.kcal, 500);
      expect(intake.protein, 30);
      expect(intake.waterMl, 250);
    });

    test('Schlaf aus dem Daily Report, wenn nichts eingetragen ist', () {
      expect(effectiveSleep(null, const Duration(hours: 7, minutes: 30)), 7.5);
      expect(effectiveSleep(BodyEntry(date: today, values: const {Measure.sleepHours: 6}), const Duration(hours: 9)), 6);
      expect(effectiveSleep(BodyEntry(date: today), null), isNull);
      final series = measureSeries(
        [BodyEntry(date: today, values: const {Measure.sleepHours: 6})],
        Measure.sleepHours,
        sleepFallback: {'2026-11-27': 8, '2026-11-28': 9},
      );
      expect([for (final p in series) p.value], [8, 6]);
    });

    test('Verlauf einer Übung: bester Wert je Training', () {
      final sessions = [
        WorkoutSession(id: 'b', startedAt: DateTime(2026, 11, 20), duration: Duration.zero, results: const [
          ExerciseResult(exerciseId: 'bank', values: {ResultMetric.weight: 60}),
          ExerciseResult(exerciseId: 'bank', values: {ResultMetric.weight: 65}),
        ]),
        WorkoutSession(id: 'a', startedAt: DateTime(2026, 11, 10), duration: Duration.zero, results: const [
          ExerciseResult(exerciseId: 'bank', values: {ResultMetric.weight: 55}),
        ]),
      ];
      expect([for (final p in exerciseSeries(sessions, 'bank', ResultMetric.weight)) p.value], [55, 65]);
    });

    test('Gesamtdauer ohne Ruhe nach der letzten Übung', () {
      const plan = TrainingPlan(id: 'p', name: 'Zirkel', steps: [
        PlanStep(exerciseId: 'a', seconds: 60, restSeconds: 30),
        PlanStep(exerciseId: 'b', seconds: 45, restSeconds: 30),
      ]);
      expect(plan.totalDuration, const Duration(seconds: 135));
    });
  });

  group('Abspielen', () {
    test('Übung → Ruhe → nächste Übung, letzte ohne Ruhe', () {
      final playback = TrainingPlayback(const [
        PlanStep(exerciseId: 'a', seconds: 10, restSeconds: 5),
        PlanStep(exerciseId: 'b', seconds: 10, restSeconds: 5),
      ]);
      expect(playback.phase, PlaybackPhase.work);
      expect(playback.tick(const Duration(seconds: 10)), isTrue);
      expect(playback.phase, PlaybackPhase.rest);
      expect(playback.remaining, const Duration(seconds: 5));
      playback.tick(const Duration(seconds: 7));
      expect(playback.stepIndex, 1);
      expect(playback.phase, PlaybackPhase.work);
      expect(playback.remaining, const Duration(seconds: 8));
      playback.tick(const Duration(seconds: 8));
      expect(playback.isDone, isTrue);
    });

    test('Vorgabezeit 0 wartet auf Weiter, Pause hält an', () {
      final playback = TrainingPlayback(const [
        PlanStep(exerciseId: 'a', seconds: 0, restSeconds: 0),
        PlanStep(exerciseId: 'b', seconds: 20, restSeconds: 0),
      ]);
      expect(playback.waitsForUser, isTrue);
      expect(playback.tick(const Duration(minutes: 5)), isFalse);
      playback.next();
      expect(playback.stepIndex, 1);
      playback.togglePause();
      playback.tick(const Duration(seconds: 15));
      expect(playback.remaining, const Duration(seconds: 20));
      playback.previous();
      expect(playback.stepIndex, 0);
    });
  });

  group('Speichern', () {
    late LifeosDatabase dbA;
    late LifeosDatabase dbB;
    late SportRepository repoA;
    late SportRepository repoB;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      dbA = LifeosDatabase(NativeDatabase.memory());
      dbB = LifeosDatabase(NativeDatabase.memory());
      final recorderA = await ChangeRecorder.open(dbA);
      final recorderB = await ChangeRecorder.open(dbB);
      repoA = SportRepository(dbA, recorderA);
      repoB = SportRepository(dbB, recorderB);
      engineA = SyncEngine(dbA, recorderA);
      engineB = SyncEngine(dbB, recorderB);
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
    });

    Future<void> exchange() async {
      await engineB.applyEntries(await engineA.entriesMissingFrom(await engineB.versionVector()));
      await engineA.applyEntries(await engineB.entriesMissingFrom(await engineA.versionVector()));
    }

    test('Gewicht am PC und Puls am Handy ergeben einen Eintrag', () async {
      await repoA.saveBody(today, {Measure.weight: 81.4});
      await repoB.saveBody(today, {Measure.restingPulse: 58});
      await exchange();
      for (final repo in [repoA, repoB]) {
        final entry = (await repo.watchBody().first).single;
        expect(entry.values[Measure.weight], 81.4);
        expect(entry.values[Measure.restingPulse], 58);
      }
    });

    test('geleerter Wert verschwindet auch auf dem anderen Gerät', () async {
      await repoA.saveBody(today, {Measure.weight: 80, Measure.height: 182});
      await exchange();
      await repoB.saveBody(today, {Measure.weight: null});
      await exchange();
      final entry = (await repoA.watchBody().first).single;
      expect(entry.values.containsKey(Measure.weight), isFalse);
      expect(entry.values[Measure.height], 182);
    });

    test('Ziele, Tracker, Übungen, Pläne und Trainings', () async {
      await repoA.setGoals(const IntakeGoals(kcal: 2200, waterMl: 2500));
      await repoA.setGoals(const IntakeGoals(kcal: 2000, waterMl: 2500));
      expect((await repoA.watchGoals().first).kcal, 2000);

      final log = await repoA.addNutrition(today, waterMl: 250);
      expect(intakeOn(await repoA.watchNutrition(from: today).first, today).waterMl, 250);
      await repoA.deleteNutrition(log);
      expect(await repoA.watchNutrition(from: today).first, isEmpty);

      final squat = await repoA.addExercise(name: 'Kniebeuge', category: ExerciseCategory.strength);
      final plan = await repoA.addPlan(name: 'Beine', kind: PlanKind.strength, steps: [PlanStep(exerciseId: squat)]);
      final stored = (await repoA.watchPlans().first).single;
      expect(stored.id, plan);
      expect(stored.steps.single.exerciseId, squat);

      await repoA.saveWorkout(
        planId: plan,
        startedAt: DateTime(2026, 11, 28, 18),
        duration: const Duration(minutes: 30),
        results: [ExerciseResult(exerciseId: squat, values: const {ResultMetric.weight: 70, ResultMetric.reps: 8})],
      );
      final workout = (await repoA.watchWorkouts().first).single;
      expect(workout.results.single.values[ResultMetric.reps], 8);
      await exchange();
      expect((await repoB.watchWorkouts().first).single.planId, plan);
    });
  });
}
