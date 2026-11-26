import 'package:drift/drift.dart';

// Alle Tabellen liegen zentral hier, siehe docs/adr/0002-drift-tabellen-zentral.md.

/// Spalten, die jede synchronisierte Fachtabelle besitzt.
mixin SyncColumns on Table {
  /// Erstellungszeitpunkt in Millisekunden seit 1970 (UTC).
  IntColumn get createdAt => integer()();

  /// Gerät, auf dem der Datensatz entstanden ist.
  TextColumn get createdBy => text()();

  /// HLC-Zeitstempel der letzten Änderung (Textform aus `Hlc.pack`).
  TextColumn get updatedHlc => text()();

  /// Gerät der letzten Änderung.
  TextColumn get updatedBy => text()();

  /// HLC-Zeitstempel der Löschung. Gesetzt bedeutet: Tombstone.
  TextColumn get deletedHlc => text().nullable()();
}

/// Gerätebezogene Schlüssel-Wert-Paare. Werden nie synchronisiert.
@DataClassName('LocalMetaEntry')
class LocalMeta extends Table {
  TextColumn get metaKey => text()();
  TextColumn get metaValue => text()();

  @override
  Set<Column> get primaryKey => {metaKey};
}

/// Änderungsprotokoll (Outbox). Ein Eintrag je Änderung, Schlüssel ist
/// (Ursprungsgerät, laufende Nummer).
@DataClassName('ChangeLogEntry')
class ChangeLog extends Table {
  TextColumn get originDevice => text()();
  IntColumn get seq => integer()();
  TextColumn get hlc => text()();

  /// Fachliche Tabelle, z. B. `tasks`.
  TextColumn get entity => text()();
  TextColumn get recordId => text()();

  /// `upsert` oder `delete`.
  TextColumn get op => text()();

  /// JSON: je Feldgruppe die neuen Werte und der Vorgänger-HLC.
  TextColumn get payload => text()();

  /// Gruppiert Änderungen, die gemeinsam gelingen müssen.
  TextColumn get txId => text()();

  @override
  Set<Column> get primaryKey => {originDevice, seq};
}

/// Aktueller HLC je Feldgruppe eines Datensatzes. Grundlage der
/// Konflikterkennung.
@DataClassName('RowClock')
class RowClocks extends Table {
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get fieldGroup => text()();
  TextColumn get hlc => text()();
  TextColumn get device => text()();

  @override
  Set<Column> get primaryKey => {entity, recordId, fieldGroup};
}

/// Gekoppelte Geräte, mit denen dieses Gerät synchronisiert.
@DataClassName('PairedDevice')
class PairedDevices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get name => text()();
  TextColumn get platform => text()();

  /// Zuletzt bekannte Adresse als `host:port`.
  TextColumn get address => text().nullable()();
  IntColumn get addedAt => integer()();
  IntColumn get lastSyncAt => integer().nullable()();

  /// Höchste eigene Änderungsnummer, die dieses Gerät bestätigt hat.
  IntColumn get ackedSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// Bei gleichzeitigen Änderungen unterlegene Werte, damit nichts
/// unbemerkt verloren geht (Architektur Abschnitt 7).
@DataClassName('SyncConflict')
class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get fieldGroup => text()();

  /// JSON der unterlegenen Werte.
  TextColumn get losingValues => text()();
  TextColumn get losingHlc => text()();
  TextColumn get winningHlc => text()();
  IntColumn get createdAt => integer()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Aufgaben (Todos und später Projekt-Unterpunkte).
@DataClassName('TaskRow')
class Tasks extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get details => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get doneAt => integer().nullable()();

  /// Fälligkeitsdatum als ISO-Datum (`2026-11-26`), ohne Uhrzeit.
  TextColumn get dueDate => text().nullable()();
  TextColumn get projectId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notizen in Markdown.
@DataClassName('NoteRow')
class Notes extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
