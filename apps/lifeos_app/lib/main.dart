import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';
import 'package:lifeos_learning/lifeos_learning.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_projects/lifeos_projects.dart';
import 'package:lifeos_security/lifeos_security.dart';
import 'package:lifeos_sport/lifeos_sport.dart';
import 'package:lifeos_tags/lifeos_tags.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'src/app.dart';
import 'src/app_providers.dart';
import 'src/bootstrap.dart';
import 'src/startup_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppServices services;
  try {
    services = await AppServices.open();
  } catch (error, stackTrace) {
    debugPrint('LifeOS konnte nicht starten: $error\n$stackTrace');
    runApp(StartupErrorApp(error: error));
    return;
  }

  // Hier verdrahtet die App, welche Implementierung welchen Port erfüllt
  // (Architektur Abschnitt 2, „Wie Module miteinander reden“).
  runApp(
    ProviderScope(
      overrides: [
        appLockControllerProvider.overrideWithValue(services.lock),
        deviceIdProvider.overrideWithValue(services.recorder.deviceId),
        syncServiceProvider.overrideWithValue(services.sync),
        taskRepositoryProvider.overrideWithValue(services.tasks),
        noteRepositoryProvider.overrideWithValue(services.notes),
        tagRepositoryProvider.overrideWithValue(services.tags),
        eventRepositoryProvider.overrideWithValue(services.events),
        financeRepositoryProvider.overrideWithValue(services.finance),
        dailyReportRepositoryProvider.overrideWithValue(services.dailyReports),
        habitRepositoryProvider.overrideWithValue(services.habits),
        projectRepositoryProvider.overrideWithValue(services.projects),
        ingredientRepositoryProvider.overrideWithValue(services.ingredients),
        recipeRepositoryProvider.overrideWithValue(services.recipes),
        shoppingRepositoryProvider.overrideWithValue(services.shopping),
        learningRepositoryProvider.overrideWithValue(services.learning),
        sportRepositoryProvider.overrideWithValue(services.sport),
        learningProjectChoicesProvider.overrideWith(
          (ref) => services.projects.watchAll().map(
                (projects) => [
                  for (final project in projects)
                    if (project.isActive) LearningProjectChoice(id: project.id, name: project.name),
                ],
              ),
        ),
        trainingPlanChoicesProvider.overrideWith(
          (ref) => services.sport.watchPlans().map(
                (plans) => [for (final plan in plans) TrainingPlanChoice(id: plan.id, name: plan.name)],
              ),
        ),
        startTrainingProvider.overrideWithValue(openPlayback),
        projectChoicesProvider.overrideWith(
          (ref) => services.projects.watchAll().map(
                (projects) => [
                  for (final project in projects)
                    if (project.isActive) ProjectChoice(id: project.id, name: project.name),
                ],
              ),
        ),
        deviceChoicesProvider.overrideWith(
          (ref) => deviceChoicesStream(services.sync, services.recorder.deviceId),
        ),
      ],
      child: LifeosApp(
        lock: services.lock,
        onResume: () {
          services.sync.syncNow();
          services.finance.generateDueRecurring();
        },
      ),
    ),
  );
}
