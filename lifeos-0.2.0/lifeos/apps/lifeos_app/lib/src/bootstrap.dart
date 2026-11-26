import 'dart:io';

import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_security/lifeos_security.dart';
import 'package:lifeos_sync/lifeos_sync.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Alle Dienste, die beim Start einmal erzeugt werden.
class AppServices {
  AppServices._({
    required this.database,
    required this.recorder,
    required this.lock,
    required this.sync,
    required this.tasks,
    required this.notes,
  });

  final LifeosDatabase database;
  final ChangeRecorder recorder;
  final AppLockController lock;
  final SyncService sync;
  final TaskRepository tasks;
  final NoteRepository notes;

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

    return AppServices._(
      database: database,
      recorder: recorder,
      lock: lock,
      sync: sync,
      tasks: TaskRepository(database, recorder),
      notes: NoteRepository(database, recorder),
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
