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
  ],
)
class LifeosDatabase extends _$LifeosDatabase {
  LifeosDatabase(super.executor);

  /// Version 1: Fundament. Version 2: gekoppelte Geräte und Konflikte.
  /// Version 3: Tags, Kalender, Finanzen.
  /// Version 4: Daily Report, Habits, Projekte; Projekt-Spalten an Notizen
  /// und Terminen, Anheften von Notizen.
  @override
  int get schemaVersion => 4;

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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
