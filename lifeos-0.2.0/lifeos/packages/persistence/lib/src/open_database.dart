import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

final RegExp _hexKey = RegExp(r'^[0-9a-f]{64}$');

/// Öffnet die verschlüsselte LifeOS-Datenbank in einem Hintergrund-Isolate.
///
/// [hexKey] sind 64 Hex-Zeichen aus dem Schlüsselspeicher des Systems.
/// Voraussetzung: Die Workspace-`pubspec.yaml` bündelt SQLite3MultipleCiphers
/// (`hooks: user_defines: sqlite3: source: sqlite3mc`).
QueryExecutor openEncryptedDatabase(File file, String hexKey) {
  if (!_hexKey.hasMatch(hexKey)) {
    throw ArgumentError('Der Datenbankschlüssel muss aus 64 Hex-Zeichen bestehen.');
  }
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      // Normales SQLite kennt dieses Pragma nicht. Ohne Verschlüsselung
      // wird nicht geöffnet.
      final hasCipher = rawDb.select('PRAGMA cipher;').isNotEmpty;
      if (!hasCipher) {
        throw StateError(
          'SQLite3MultipleCiphers ist nicht eingebunden. Prüfe '
          'hooks.user_defines.sqlite3.source in der Workspace-pubspec.yaml.',
        );
      }
      // SQLCipher-4-Format, damit die Datei mit gängigen Werkzeugen prüfbar ist.
      rawDb.execute("PRAGMA cipher = 'sqlcipher';");
      rawDb.execute('PRAGMA legacy = 4;');
      rawDb.execute("PRAGMA key = '$hexKey';");
      // Prüft den Schlüssel sofort statt erst bei der ersten Abfrage.
      rawDb.select('SELECT count(*) FROM sqlite_master;');
    },
  );
}
