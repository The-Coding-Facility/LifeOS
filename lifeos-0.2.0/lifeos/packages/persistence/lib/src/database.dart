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
  ],
)
class LifeosDatabase extends _$LifeosDatabase {
  LifeosDatabase(super.executor);

  /// Version 1: Fundament. Version 2: gekoppelte Geräte und Konflikte.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(pairedDevices);
            await migrator.createTable(syncConflicts);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
