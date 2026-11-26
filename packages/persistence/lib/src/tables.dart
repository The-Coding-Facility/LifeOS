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

/// Tags aller Module. `scope` trennt die Bereiche (`calendar`, `finance`).
/// Die ID entsteht deterministisch aus Bereich und Name, damit derselbe Tag
/// auf zwei Geräten zum selben Datensatz wird.
@DataClassName('TagRow')
class Tags extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get name => text()();

  /// Index in der festen Farbpalette des Design-Systems.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// Monatsbudget in Cent, nur bei Finanz-Tags.
  IntColumn get monthlyLimitCents => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Termine. Zeitpunkte in UTC-Millisekunden; ganztägige Termine beginnen um
/// UTC-Mitternacht ihres Kalendertags, das Ende ist exklusiv.
@DataClassName('CalendarEventRow')
class CalendarEvents extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  IntColumn get startAt => integer()();
  IntColumn get endAt => integer()();

  /// JSON `{freq, interval, weekdays, until}` oder leer.
  TextColumn get recurrence => text().nullable()();

  /// JSON-Liste ausgelassener Vorkommen (`yyyy-mm-dd`).
  TextColumn get exdates => text().withDefault(const Constant('[]'))();

  /// JSON-Liste von Tag-IDs.
  TextColumn get tagIds => text().withDefault(const Constant('[]'))();

  /// Minuten vor Beginn; leer = keine Erinnerung.
  IntColumn get reminderMinutes => integer().nullable()();

  /// JSON-Liste von Geräte-IDs; `["*"]` = alle Geräte.
  TextColumn get reminderDevices => text().withDefault(const Constant('["*"]'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Buchungen. `kind`: `income`, `expense`, `saving`, `withdrawal`.
/// Der Betrag ist immer positiv, das Vorzeichen folgt aus `kind`.
@DataClassName('FinanceEntryRow')
class FinanceEntries extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  IntColumn get amountCents => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Buchungsdatum `yyyy-mm-dd`.
  TextColumn get date => text()();
  TextColumn get tagIds => text().withDefault(const Constant('[]'))();
  TextColumn get savingGoalId => text().nullable()();

  /// Gesetzt, wenn die Buchung aus einem Dauerauftrag stammt.
  TextColumn get recurringId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Daueraufträge. `freq`: `weekly`, `monthly`, `yearly`.
@DataClassName('FinanceRecurringRow')
class FinanceRecurring extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  IntColumn get amountCents => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get tagIds => text().withDefault(const Constant('[]'))();
  TextColumn get freq => text()();
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sparziele.
@DataClassName('SavingGoalRow')
class SavingGoals extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get targetCents => integer()();
  TextColumn get targetDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
