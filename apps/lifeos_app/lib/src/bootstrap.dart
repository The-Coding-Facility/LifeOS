import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_projects/lifeos_projects.dart';
import 'package:lifeos_security/lifeos_security.dart';
import 'package:lifeos_sync/lifeos_sync.dart';
import 'package:lifeos_tags/lifeos_tags.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'reminders/reminder_service.dart';
import 'reminders/reminder_sinks.dart';

/// Alle Dienste, die beim Start einmal erzeugt werden.
class AppServices {
  AppServices._({
    required this.database,
    required this.recorder,
    required this.lock,
    required this.sync,
    required this.tasks,
    required this.notes,
    required this.tags,
    required this.events,
    required this.finance,
    required this.dailyReports,
    required this.habits,
    required this.projects,
    required this.ingredients,
    required this.recipes,
    required this.shopping,
    required this.reminders,
  });

  final LifeosDatabase database;
  final ChangeRecorder recorder;
  final AppLockController lock;
  final SyncService sync;
  final TaskRepository tasks;
  final NoteRepository notes;
  final TagRepository tags;
  final EventRepository events;
  final FinanceRepository finance;
  final DailyReportRepository dailyReports;
  final HabitRepository habits;
  final ProjectRepository projects;
  final IngredientRepository ingredients;
  final RecipeRepository recipes;
  final ShoppingRepository shopping;

  /// `null`, wenn die Plattform keine Benachrichtigungen kann oder das
  /// Einrichten fehlschlug. Die App läuft dann ohne Erinnerungen.
  final ReminderService? reminders;

  /// Öffnet die verschlüsselte Datenbank und baut die Dienste auf.
  static Future<AppServices> open() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'lifeos.db'));

    final keyStore = DatabaseKeyStore();
    var key = await keyStore.read();
    if (key == null) {
      if (await file.exists()) {
        throw StateError(
          'Die Datenbank existiert, aber ihr Schlüssel fehlt im Schlüsselspeicher. '
          'Die Daten lassen sich nur aus einem Backup oder über ein gekoppeltes Gerät '
          'wiederherstellen. Die Datei wurde nicht verändert: ${file.path}',
        );
      }
      key = await keyStore.create();
    }

    final database = LifeosDatabase(openEncryptedDatabase(file, key));
    final recorder = await ChangeRecorder.open(database);
    final lock = AppLockController(store: SecurityStore(LocalMetaStore(database)));
    await lock.init();

    final sync = await SyncService.create(
      db: database,
      recorder: recorder,
      platform: Platform.operatingSystem,
      defaultName: _defaultDeviceName(),
    );
    await sync.start();

    final events = EventRepository(database, recorder);
    final finance = FinanceRepository(database, recorder);
    await finance.generateDueRecurring();

    ReminderService? reminders;
    try {
      final sink = await createReminderSink();
      if (sink != null) {
        reminders = ReminderService(events: events.watchAll(), deviceId: recorder.deviceId, sink: sink)
          ..start();
      }
    } on Object catch (error, stackTrace) {
      debugPrint('Erinnerungen sind nicht verfügbar: $error\n$stackTrace');
    }

    return AppServices._(
      database: database,
      recorder: recorder,
      lock: lock,
      sync: sync,
      tasks: TaskRepository(database, recorder),
      notes: NoteRepository(database, recorder),
      tags: TagRepository(database, recorder),
      events: events,
      finance: finance,
      dailyReports: DailyReportRepository(database, recorder),
      habits: HabitRepository(database, recorder),
      projects: ProjectRepository(database, recorder),
      ingredients: IngredientRepository(database, recorder),
      recipes: RecipeRepository(database, recorder),
      shopping: ShoppingRepository(database, recorder, finance),
      reminders: reminders,
    );
  }

  static String _defaultDeviceName() {
    if (Platform.isAndroid) return 'Android-Handy';
    if (Platform.isIOS) return 'iPhone';
    try {
      return Platform.localHostname;
    } on Object {
      return 'PC';
    }
  }
}
