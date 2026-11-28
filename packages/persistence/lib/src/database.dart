import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// Die eine lokale Datenbank eines Geräts.
///
/// Den Code in `database.g.dart` erzeugt Drift:
/// `dart run build_runner build --delete-conflicting-outputs`
@DriftDatabase(
  tables: [
    LocalMeta,
    ChangeLog,
    RowClocks,
    PairedDevices,
    SyncConflicts,
    Tasks,
    Notes,
    Tags,
    CalendarEvents,
    FinanceEntries,
    FinanceRecurring,
    SavingGoals,
    DailyReports,
    Habits,
    HabitChecks,
    Projects,
    Ingredients,
    Recipes,
    ShoppingItems,
    LearningAreas,
    GlossaryEntries,
    Flashcards,
    LearningResources,
    StudySessions,
    BodyMeasurements,
    NutritionLogs,
    SportGoals,
    Exercises,
    TrainingPlans,
    WorkoutSessions,
  ],
)
class LifeosDatabase extends _$LifeosDatabase {
  LifeosDatabase(super.executor);

  /// Version 1: Fundament. Version 2: gekoppelte Geräte und Konflikte.
  /// Version 3: Tags, Kalender, Finanzen.
  /// Version 4: Daily Report, Habits, Projekte; Projekt-Spalten an Notizen
  /// und Terminen, Anheften von Notizen.
  /// Version 5: Zutaten, Rezepte, Einkaufsliste.
  /// Version 6: Lernen und Sport; Lernbereich an Notizen, Trainingsplan an
  /// Terminen.
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(pairedDevices);
            await migrator.createTable(syncConflicts);
          }
          if (from < 3) {
            await migrator.createTable(tags);
            await migrator.createTable(calendarEvents);
            await migrator.createTable(financeEntries);
            await migrator.createTable(financeRecurring);
            await migrator.createTable(savingGoals);
          }
          if (from < 4) {
            await migrator.createTable(dailyReports);
            await migrator.createTable(habits);
            await migrator.createTable(habitChecks);
            await migrator.createTable(projects);
            await migrator.addColumn(notes, notes.projectId);
            await migrator.addColumn(notes, notes.pinned);
            // Bei einem Sprung von 2 auf 4 hat createTable die Spalte oben
            // schon angelegt.
            if (from == 3) {
              await migrator.addColumn(calendarEvents, calendarEvents.projectId);
            }
          }
          if (from < 5) {
            await migrator.createTable(ingredients);
            await migrator.createTable(recipes);
            await migrator.createTable(shoppingItems);
          }
          if (from < 6) {
            for (final table in <TableInfo<Table, dynamic>>[
              learningAreas,
              glossaryEntries,
              flashcards,
              learningResources,
              studySessions,
              bodyMeasurements,
              nutritionLogs,
              sportGoals,
              exercises,
              trainingPlans,
              workoutSessions,
            ]) {
              await migrator.createTable(table);
            }
            await migrator.addColumn(notes, notes.learningAreaId);
            // Vor Schema 3 legt createTable die Termine schon mit der Spalte an.
            if (from >= 3) {
              await migrator.addColumn(calendarEvents, calendarEvents.trainingPlanId);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
