import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../model.dart';
import '../providers.dart';
import '../sport_math.dart';
import 'sport_page.dart';

/// Dashboard-Kachel: heutige Aufnahme, Wasser-Knopf, letztes Training.
class SportTile extends ConsumerWidget {
  const SportTile({super.key, required this.onOpen, this.clock});

  final VoidCallback onOpen;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly((clock ?? DateTime.now)());
    final intake = intakeOn(ref.watch(nutritionLogsProvider).value ?? const <NutritionLog>[], today);
    final goals = ref.watch(sportGoalsProvider).value ?? const IntakeGoals();
    final workouts = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
    final plans = {for (final p in ref.watch(trainingPlansProvider).value ?? const <TrainingPlan>[]) p.id: p.name};
    final last = workouts.firstOrNull;

    return SectionCard(
      title: 'Sport heute',
      icon: Icons.fitness_center,
      action: TextButton(onPressed: onOpen, child: const Text('Öffnen')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntakeRow(label: 'kcal', value: intake.kcal, goal: goals.kcal, unit: ''),
          IntakeRow(label: 'Wasser', value: intake.waterMl, goal: goals.waterMl, unit: 'ml'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.read(sportRepositoryProvider).addNutrition(today, label: 'Wasser', waterMl: 250),
              icon: const Icon(Icons.water_drop_outlined),
              label: const Text('+250 ml'),
            ),
          ),
          Text(
            last == null
                ? 'Noch kein Training.'
                : 'Letztes Training: ${plans[last.planId] ?? 'Training'} am ${formatDateShort(last.startedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
