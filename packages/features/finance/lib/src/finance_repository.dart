import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'finance_math.dart';
import 'model.dart';
import 'recurring.dart';

/// Lesen und Schreiben von Buchungen, Daueraufträgen und Sparzielen.
///
/// Feldgruppen: Buchungen `amount` (Art, Betrag), `title`, `date`, `tags`,
/// `link` (Sparziel, Dauerauftrag); Daueraufträge `amount`, `title`, `tags`,
/// `schedule`; Sparziele `name`, `target`.
class FinanceRepository {
  FinanceRepository(this._db, this._recorder, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const String entriesEntity = 'finance_entries';
  static const String recurringEntity = 'finance_recurring';
  static const String goalsEntity = 'saving_goals';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;
  final DateTime Function() _clock;

  // ---------------------------------------------------------------- Lesen

  /// Alle Buchungen, neueste zuerst.
  Stream<List<FinanceEntry>> watchEntries() {
    final query = _db.select(_db.financeEntries)
      ..where((entry) => entry.deletedHlc.isNull())
      ..orderBy([
        (entry) => OrderingTerm.desc(entry.date),
        (entry) => OrderingTerm.desc(entry.createdAt),
      ]);
    return query.watch().map((rows) => [for (final row in rows) _toEntry(row)]);
  }

  Stream<List<RecurringRule>> watchRecurring() {
    final query = _db.select(_db.financeRecurring)
      ..where((rule) => rule.deletedHlc.isNull())
      ..orderBy([(rule) => OrderingTerm.asc(rule.title)]);
    return query.watch().map((rows) => [for (final row in rows) _toRule(row)]);
  }

  Stream<List<SavingGoal>> watchGoals() {
    final query = _db.select(_db.savingGoals)
      ..where((goal) => goal.deletedHlc.isNull())
      ..orderBy([(goal) => OrderingTerm.asc(goal.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _toGoal(row)]);
  }

  // ------------------------------------------------------------ Buchungen

  Future<String> addEntry(EntryDraft draft) {
    return _db.transaction(() => _insertEntry(Ids.newId(), _entryColumns(draft)));
  }

  Future<void> updateEntry(String id, EntryDraft draft) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.financeEntries)
            ..where((entry) => entry.id.equals(id) & entry.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final wanted = {
        ..._entryColumns(draft),
        'recurring_id': row.recurringId,
      };
      final existing = <String, Object?>{
        'kind': row.kind,
        'amount_cents': row.amountCents,
        'title': row.title,
        'date': row.date,
        'tag_ids': row.tagIds,
        'saving_goal_id': row.savingGoalId,
        'recurring_id': row.recurringId,
      };
      final groups = _changedGroups(_entryGroups, wanted, existing);
      if (groups.isEmpty) return;
      await _recordAndWrite(entriesEntity, _db.financeEntries, id, groups);
    });
  }

  Future<void> deleteEntry(String id) => _delete(entriesEntity, _db.financeEntries, id);

  // -------------------------------------------------------- Daueraufträge

  /// Legt einen Dauerauftrag an und bucht sofort alles bis heute Fällige.
  Future<String> addRecurring(RecurringDraft draft) async {
    final id = await _db.transaction(() async {
      final id = Ids.newId();
      final columns = _recurringColumns(draft);
      final hlc = await _recordAll(recurringEntity, id, _recurringGroups, columns);
      await _db.into(_db.financeRecurring).insert(
            FinanceRecurringCompanion.insert(
              id: id,
              kind: columns['kind']! as String,
              amountCents: columns['amount_cents']! as int,
              title: Value(columns['title']! as String),
              tagIds: Value(columns['tag_ids']! as String),
              freq: columns['freq']! as String,
              intervalCount: Value(columns['interval_count']! as int),
              startDate: columns['start_date']! as String,
              endDate: Value(columns['end_date'] as String?),
              createdAt: _nowMillis(),
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
    await generateDueRecurring();
    return id;
  }

  /// Ändert einen Dauerauftrag. Bereits gebuchte Beträge bleiben unverändert.
  Future<void> updateRecurring(String id, RecurringDraft draft) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.financeRecurring)
            ..where((rule) => rule.id.equals(id) & rule.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final existing = <String, Object?>{
        'kind': row.kind,
        'amount_cents': row.amountCents,
        'title': row.title,
        'tag_ids': row.tagIds,
        'freq': row.freq,
        'interval_count': row.intervalCount,
        'start_date': row.startDate,
        'end_date': row.endDate,
      };
      final groups = _changedGroups(_recurringGroups, _recurringColumns(draft), existing);
      if (groups.isEmpty) return;
      await _recordAndWrite(recurringEntity, _db.financeRecurring, id, groups);
    });
    await generateDueRecurring();
  }

  /// Beendet einen Dauerauftrag. Gebuchte Beträge bleiben erhalten.
  Future<void> deleteRecurring(String id) => _delete(recurringEntity, _db.financeRecurring, id);

  /// Bucht alle fälligen Beträge aller Daueraufträge bis heute. Gibt die Zahl
  /// neuer Buchungen zurück. Mehrfaches Aufrufen erzeugt nichts doppelt; eine
  /// gelöschte erzeugte Buchung bleibt gelöscht.
  Future<int> generateDueRecurring({DateTime? today}) {
    final day = dateOnly(today ?? _clock());
    return _db.transaction(() async {
      final rules = await (_db.select(_db.financeRecurring)..where((rule) => rule.deletedHlc.isNull())).get();
      var created = 0;
      for (final row in rules) {
        final rule = _toRule(row);
        for (final date in dueDates(rule, today: day)) {
          final id = recurringEntryId(rule.id, date);
          final exists = await (_db.select(_db.financeEntries)..where((entry) => entry.id.equals(id)))
              .getSingleOrNull();
          if (exists != null) continue;
          await _insertEntry(id, {
            'kind': rule.kind.key,
            'amount_cents': rule.amountCents,
            'title': rule.title,
            'date': isoDate(date),
            'tag_ids': jsonEncode(rule.tagIds),
            'saving_goal_id': null,
            'recurring_id': rule.id,
          });
          created++;
        }
      }
      return created;
    });
  }

  // ------------------------------------------------------------ Sparziele

  Future<String> addGoal(String name, int targetCents, {DateTime? targetDate}) {
    final cleanName = _requireText(name, 'Ein Sparziel braucht einen Namen.');
    return _db.transaction(() async {
      final id = Ids.newId();
      final columns = <String, Object?>{
        'name': cleanName,
        'target_cents': targetCents,
        'target_date': targetDate == null ? null : isoDate(targetDate),
      };
      final hlc = await _recordAll(goalsEntity, id, _goalGroups, columns);
      await _db.into(_db.savingGoals).insert(
            SavingGoalsCompanion.insert(
              id: id,
              name: cleanName,
              targetCents: targetCents,
              targetDate: Value(columns['target_date'] as String?),
              createdAt: _nowMillis(),
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
  }

  Future<void> updateGoal(String id, {String? name, int? targetCents, DateTime? targetDate, bool clearDate = false}) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.savingGoals)..where((goal) => goal.id.equals(id) & goal.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final wanted = <String, Object?>{
        'name': name == null ? row.name : _requireText(name, 'Ein Sparziel braucht einen Namen.'),
        'target_cents': targetCents ?? row.targetCents,
        'target_date': clearDate ? null : (targetDate == null ? row.targetDate : isoDate(targetDate)),
      };
      final existing = <String, Object?>{
        'name': row.name,
        'target_cents': row.targetCents,
        'target_date': row.targetDate,
      };
      final groups = _changedGroups(_goalGroups, wanted, existing);
      if (groups.isEmpty) return;
      await _recordAndWrite(goalsEntity, _db.savingGoals, id, groups);
    });
  }

  /// Löscht ein Sparziel. Was darauf lag, kommt per Entnahme zurück aufs
  /// Konto, damit der Kontostand stimmt.
  Future<void> deleteGoal(String id) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.savingGoals)..where((goal) => goal.id.equals(id) & goal.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final entries = await (_db.select(_db.financeEntries)
            ..where((entry) => entry.savingGoalId.equals(id) & entry.deletedHlc.isNull()))
          .get();
      final saved = savedFor(id, entries.map(_toEntry));
      if (saved > 0) {
        await _insertEntry(Ids.newId(), {
          'kind': EntryKind.withdrawal.key,
          'amount_cents': saved,
          'title': 'Sparziel aufgelöst: ${row.name}',
          'date': isoDate(_clock()),
          'tag_ids': '[]',
          'saving_goal_id': id,
          'recurring_id': null,
        });
      }
      await _delete(goalsEntity, _db.savingGoals, id);
    });
  }

  /// Legt [cents] auf das Sparziel [goalId]; der Kontostand sinkt.
  Future<String> deposit(String goalId, int cents, {DateTime? date, String? goalName}) => addEntry(
        EntryDraft(
          kind: EntryKind.saving,
          amountCents: cents,
          date: date ?? _clock(),
          title: goalName == null ? 'Sparziel' : 'Sparziel: $goalName',
          savingGoalId: goalId,
        ),
      );

  /// Nimmt [cents] vom Sparziel [goalId]; der Kontostand steigt.
  Future<String> withdraw(String goalId, int cents, {DateTime? date, String? goalName}) => addEntry(
        EntryDraft(
          kind: EntryKind.withdrawal,
          amountCents: cents,
          date: date ?? _clock(),
          title: goalName == null ? 'Sparziel' : 'Aus Sparziel: $goalName',
          savingGoalId: goalId,
        ),
      );

  // ------------------------------------------------------------- Intern

  static const Map<String, List<String>> _entryGroups = {
    'amount': ['kind', 'amount_cents'],
    'title': ['title'],
    'date': ['date'],
    'tags': ['tag_ids'],
    'link': ['saving_goal_id', 'recurring_id'],
  };

  static const Map<String, List<String>> _recurringGroups = {
    'amount': ['kind', 'amount_cents'],
    'title': ['title'],
    'tags': ['tag_ids'],
    'schedule': ['freq', 'interval_count', 'start_date', 'end_date'],
  };

  static const Map<String, List<String>> _goalGroups = {
    'name': ['name'],
    'target': ['target_cents', 'target_date'],
  };

  Future<String> _insertEntry(String id, Map<String, Object?> columns) async {
    final hlc = await _recordAll(entriesEntity, id, _entryGroups, columns);
    await _db.into(_db.financeEntries).insert(
          FinanceEntriesCompanion.insert(
            id: id,
            kind: columns['kind']! as String,
            amountCents: columns['amount_cents']! as int,
            title: Value(columns['title']! as String),
            date: columns['date']! as String,
            tagIds: Value(columns['tag_ids']! as String),
            savingGoalId: Value(columns['saving_goal_id'] as String?),
            recurringId: Value(columns['recurring_id'] as String?),
            createdAt: _nowMillis(),
            createdBy: _recorder.deviceId,
            updatedHlc: hlc.pack(),
            updatedBy: _recorder.deviceId,
          ),
        );
    return id;
  }

  Future<Hlc> _recordAll(
    String entity,
    String id,
    Map<String, List<String>> groupColumns,
    Map<String, Object?> columns,
  ) {
    return _recorder.record(
      entity: entity,
      recordId: id,
      op: ChangeOp.upsert,
      groups: {
        for (final MapEntry(key: group, value: names) in groupColumns.entries)
          group: {for (final name in names) name: columns[name]},
      },
    );
  }

  static Map<String, Map<String, Object?>> _changedGroups(
    Map<String, List<String>> groupColumns,
    Map<String, Object?> wanted,
    Map<String, Object?> existing,
  ) {
    return {
      for (final MapEntry(key: group, value: names) in groupColumns.entries)
        if (names.any((name) => wanted[name] != existing[name]))
          group: {for (final name in names) name: wanted[name]},
    };
  }

  /// Protokolliert [groups] und schreibt dieselben Spaltenwerte per SQL.
  Future<void> _recordAndWrite(
    String entity,
    TableInfo<Table, Object?> table,
    String id,
    Map<String, Map<String, Object?>> groups,
  ) async {
    final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
    final values = {for (final group in groups.values) ...group};
    final assignments = [...values.keys.map((column) => '$column = ?'), 'updated_hlc = ?', 'updated_by = ?'];
    await _db.customUpdate(
      'UPDATE $entity SET ${assignments.join(', ')} WHERE id = ?',
      variables: [
        for (final value in values.values) _variable(value),
        Variable<String>(hlc.pack()),
        Variable<String>(_recorder.deviceId),
        Variable<String>(id),
      ],
      updates: {table},
    );
  }

  Future<void> _delete(String entity, TableInfo<Table, Object?> table, String id) {
    return _db.transaction(() async {
      final present = await _db.customSelect(
        'SELECT 1 AS present FROM $entity WHERE id = ? AND deleted_hlc IS NULL',
        variables: [Variable<String>(id)],
      ).getSingleOrNull();
      if (present == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await _db.customUpdate(
        'UPDATE $entity SET deleted_hlc = ?, updated_hlc = ?, updated_by = ? WHERE id = ?',
        variables: [
          Variable<String>(hlc.pack()),
          Variable<String>(hlc.pack()),
          Variable<String>(_recorder.deviceId),
          Variable<String>(id),
        ],
        updates: {table},
      );
    });
  }

  static Variable<Object> _variable(Object? value) => switch (value) {
        null => const Variable<String>(null),
        final bool flag => Variable<bool>(flag),
        final int number => Variable<int>(number),
        final String text => Variable<String>(text),
        _ => throw ArgumentError.value(value, 'value', 'Nicht unterstützter Typ'),
      };

  static Map<String, Object?> _entryColumns(EntryDraft draft) {
    if (draft.amountCents <= 0) {
      throw ArgumentError('Der Betrag muss größer als 0 sein.');
    }
    return {
      'kind': draft.kind.key,
      'amount_cents': draft.amountCents,
      'title': draft.title.trim(),
      'date': isoDate(draft.date),
      'tag_ids': jsonEncode(draft.tagIds),
      'saving_goal_id': draft.savingGoalId,
      'recurring_id': null,
    };
  }

  static Map<String, Object?> _recurringColumns(RecurringDraft draft) {
    if (draft.amountCents <= 0) {
      throw ArgumentError('Der Betrag muss größer als 0 sein.');
    }
    return {
      'kind': draft.kind.key,
      'amount_cents': draft.amountCents,
      'title': draft.title.trim(),
      'tag_ids': jsonEncode(draft.tagIds),
      'freq': draft.freq.key,
      'interval_count': draft.interval < 1 ? 1 : draft.interval,
      'start_date': isoDate(draft.startDate),
      'end_date': draft.endDate == null ? null : isoDate(draft.endDate!),
    };
  }

  static String _requireText(String text, String message) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError(message);
    return trimmed;
  }

  static int _nowMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static List<String> _decodeList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return [for (final item in decoded) if (item is String) item];
    } on FormatException {
      // Kaputte Daten ignorieren.
    }
    return const [];
  }

  static DateTime _parseDate(String text) {
    try {
      return parseIsoDate(text);
    } on FormatException {
      return DateTime(1970);
    }
  }

  static FinanceEntry _toEntry(FinanceEntryRow row) => FinanceEntry(
        id: row.id,
        kind: EntryKind.fromKey(row.kind),
        amountCents: row.amountCents,
        title: row.title,
        date: _parseDate(row.date),
        tagIds: _decodeList(row.tagIds),
        savingGoalId: row.savingGoalId,
        recurringId: row.recurringId,
      );

  static RecurringRule _toRule(FinanceRecurringRow row) => RecurringRule(
        id: row.id,
        kind: EntryKind.fromKey(row.kind),
        amountCents: row.amountCents,
        title: row.title,
        tagIds: _decodeList(row.tagIds),
        freq: RecurringFreq.fromKey(row.freq),
        interval: row.intervalCount,
        startDate: _parseDate(row.startDate),
        endDate: row.endDate == null ? null : _parseDate(row.endDate!),
      );

  static SavingGoal _toGoal(SavingGoalRow row) => SavingGoal(
        id: row.id,
        name: row.name,
        targetCents: row.targetCents,
        targetDate: row.targetDate == null ? null : _parseDate(row.targetDate!),
      );
}
