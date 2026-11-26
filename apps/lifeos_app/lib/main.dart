import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_security/lifeos_security.dart';
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
