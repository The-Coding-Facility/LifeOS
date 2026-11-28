import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model.dart';
import 'sport_repository.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final sportRepositoryProvider = Provider<SportRepository>(
  (ref) => throw UnimplementedError('sportRepositoryProvider muss in main() überschrieben werden.'),
);

final bodyEntriesProvider = StreamProvider<List<BodyEntry>>((ref) => ref.watch(sportRepositoryProvider).watchBody());

final nutritionLogsProvider = StreamProvider<List<NutritionLog>>((ref) {
  final now = DateTime.now();
  return ref.watch(sportRepositoryProvider).watchNutrition(from: DateTime(now.year - 1, now.month, now.day));
});

final sportGoalsProvider = StreamProvider<IntakeGoals>((ref) => ref.watch(sportRepositoryProvider).watchGoals());

final exercisesProvider = StreamProvider<List<Exercise>>((ref) => ref.watch(sportRepositoryProvider).watchExercises());

final trainingPlansProvider = StreamProvider<List<TrainingPlan>>((ref) => ref.watch(sportRepositoryProvider).watchPlans());

final workoutSessionsProvider =
    StreamProvider<List<WorkoutSession>>((ref) => ref.watch(sportRepositoryProvider).watchWorkouts());
