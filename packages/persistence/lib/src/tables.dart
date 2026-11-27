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

  /// Gesetzt bei Unterpunkten eines Projekts.
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

  /// Projekt, in dessen Dashboard die Notiz erscheint (seit Schema 4).
  TextColumn get projectId => text().nullable()();

  /// An die Übersicht angeheftet (seit Schema 4).
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

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

  /// Projekt, zu dem der Termin gehört (seit Schema 4).
  TextColumn get projectId => text().nullable()();

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

/// Daily Reports. Die ID entsteht aus dem Datum, damit es je Tag genau einen
/// Bericht gibt, auch wenn zwei Geräte ihn offline anlegen.
@DataClassName('DailyReportRow')
class DailyReports extends Table with SyncColumns {
  TextColumn get id => text()();

  /// Tag des Berichts, `yyyy-mm-dd`.
  TextColumn get date => text()();
  TextColumn get successes => text().withDefault(const Constant(''))();
  TextColumn get learned => text().withDefault(const Constant(''))();
  BoolColumn get calendarDone => boolean().withDefault(const Constant(false))();
  BoolColumn get kcalGoalMet => boolean().withDefault(const Constant(false))();
  BoolColumn get waterGoalMet => boolean().withDefault(const Constant(false))();

  /// Uhrzeiten als `HH:mm`.
  TextColumn get sleptAt => text().nullable()();
  TextColumn get wokeAt => text().nullable()();
  TextColumn get activities => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gewohnheiten. `weekdays`: JSON-Liste 1 (Mo) bis 7 (So), leer = täglich.
@DataClassName('HabitRow')
class Habits extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  TextColumn get weekdays => text().withDefault(const Constant('[]'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Haken eines Habits an einem Tag. ID aus Habit und Datum; abhaken und
/// zurücknehmen ändern nur `done`.
@DataClassName('HabitCheckRow')
class HabitChecks extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  TextColumn get date => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Projekte. `status`: `active` oder `done`.
@DataClassName('ProjectRow')
class Projects extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Deadline `yyyy-mm-dd` oder leer.
  TextColumn get deadline => text().nullable()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Zutaten. Die ID entsteht aus dem normalisierten Namen, damit „Vollmilch“
/// auf zwei Geräten derselbe Datensatz wird. Nährwerte je 100 g bzw. 100 ml,
/// bei `piece` je Stück.
@DataClassName('IngredientRow')
class Ingredients extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `g`, `ml` oder `piece`.
  TextColumn get unit => text().withDefault(const Constant('g'))();
  RealColumn get kcal => real().withDefault(const Constant(0.0))();
  RealColumn get protein => real().withDefault(const Constant(0.0))();
  RealColumn get fat => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rezepte. `ingredients`: JSON-Liste `[{"id": Zutat-ID, "amount": Menge}]`.
@DataClassName('RecipeRow')
class Recipes extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get title => text()();

  /// Zubereitungszeit in Minuten.
  IntColumn get minutes => integer().nullable()();
  IntColumn get servings => integer().withDefault(const Constant(1))();
  TextColumn get tagIds => text().withDefault(const Constant('[]'))();
  TextColumn get ingredients => text().withDefault(const Constant('[]'))();
  TextColumn get preparation => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Einträge der Einkaufsliste, aus Rezepten oder von Hand.
@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get ingredientId => text().nullable()();
  TextColumn get recipeId => text().nullable()();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
