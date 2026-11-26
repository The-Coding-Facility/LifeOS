import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'entity_schema.dart';
import 'sync_entry.dart';
import 'sync_errors.dart';

/// Kern des Sync: Versionsvektor bestimmen, fehlende Einträge liefern,
/// empfangene Einträge zusammenführen (Architektur Abschnitte 5 und 7).
///
/// Regeln beim Zusammenführen je Feldgruppe:
/// - Der höhere HLC gewinnt. Alle Geräte kommen so zum selben Ergebnis.
/// - Waren die Änderungen gleichzeitig (Vorgänger passt nicht) und die Werte
///   verschieden, wird der unterlegene Wert als Konflikt gespeichert.
/// - Löschen ist eine eigene Feldgruppe. Spätere Bearbeitungen machen eine
///   Löschung nicht rückgängig.
/// - Das Anwenden ist idempotent: bekannte Einträge werden übersprungen.
class SyncEngine {
  SyncEngine(this._db, this._recorder, {Map<String, EntitySchema>? schemas})
      : _schemas = schemas ?? defaultEntitySchemas;

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;
  final Map<String, EntitySchema> _schemas;

  String get deviceId => _recorder.deviceId;

  int get schemaVersion => _db.schemaVersion;

  /// Je Ursprungsgerät die höchste vorhandene Änderungsnummer.
  Future<Map<String, int>> versionVector() async {
    final rows = await _db.customSelect(
      'SELECT origin_device, MAX(seq) AS max_seq FROM change_log GROUP BY origin_device',
      readsFrom: {_db.changeLog},
    ).get();
    return {
      for (final row in rows) row.read<String>('origin_device'): row.read<int>('max_seq'),
    };
  }

  /// Höchste Nummer der eigenen Änderungen.
  Future<int> ownLatestSeq() async => (await versionVector())[deviceId] ?? 0;

  /// Einträge, die ein Gerät mit dem Vektor [remote] noch nicht hat,
  /// sortiert nach HLC. Je Ursprungsgerät immer ein lückenloser Anfang.
  Future<List<SyncEntry>> entriesMissingFrom(
    Map<String, int> remote, {
    int limit = 500,
  }) async {
    final local = await versionVector();
    final candidates = <ChangeLogEntry>[];
    for (final MapEntry(key: origin, value: localMax) in local.entries) {
      final known = remote[origin] ?? 0;
      if (localMax <= known) continue;
      final query = _db.select(_db.changeLog)
        ..where((entry) => entry.originDevice.equals(origin) & entry.seq.isBiggerThanValue(known))
        ..orderBy([(entry) => OrderingTerm.asc(entry.seq)])
        ..limit(limit);
      candidates.addAll(await query.get());
    }
    candidates.sort((a, b) => a.hlc.compareTo(b.hlc));
    return candidates.take(limit).map(SyncEntry.fromRow).toList(growable: false);
  }

  /// Wendet empfangene Einträge in einer Transaktion an.
  /// Gibt die Zahl der neu übernommenen Einträge zurück.
  Future<int> applyEntries(List<SyncEntry> entries) {
    final sorted = [...entries]..sort((a, b) => a.hlc.compareTo(b.hlc));
    return _db.transaction(() async {
      final vector = await versionVector();
      var applied = 0;
      for (final entry in sorted) {
        final expected = (vector[entry.originDevice] ?? 0) + 1;
        if (entry.seq < expected) continue;
        if (entry.seq > expected) {
          throw SyncGapException(entry.originDevice, expected, entry.seq);
        }
        await _recorder.observe(Hlc.parse(entry.hlc));
        await _apply(entry);
        await _db.into(_db.changeLog).insert(entry.toCompanion(), mode: InsertMode.insertOrIgnore);
        vector[entry.originDevice] = entry.seq;
        applied++;
      }
      return applied;
    });
  }

  /// Anzahl der noch nicht aufgelösten Konflikte.
  Future<int> openConflictCount() async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM sync_conflicts WHERE resolved = 0',
      readsFrom: {_db.syncConflicts},
    ).getSingle();
    return row.read<int>('c');
  }

  Future<void> _apply(SyncEntry entry) async {
    final schema = _schemas[entry.entity];
    // Unbekannte Tabellen (neuere App-Version) bleiben nur im Protokoll,
    // damit sie an andere Geräte weitergereicht werden können.
    if (schema == null) return;
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    await _ensureRow(schema, entry);
    for (final group in payload.entries) {
      final data = group.value as Map<String, dynamic>;
      final values = (data['values'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      await _applyGroup(schema, entry, group.key, data['prev'] as String?, values);
    }
    await _db.customUpdate(
      'UPDATE ${schema.table} SET updated_hlc = ?, updated_by = ? '
      'WHERE id = ? AND updated_hlc < ?',
      variables: [
        Variable<String>(entry.hlc),
        Variable<String>(entry.originDevice),
        Variable<String>(entry.recordId),
        Variable<String>(entry.hlc),
      ],
      updates: {schema.tableOf(_db)},
    );
  }

  Future<void> _ensureRow(EntitySchema schema, SyncEntry entry) async {
    final existing = await _db.customSelect(
      'SELECT 1 AS present FROM ${schema.table} WHERE id = ?',
      variables: [Variable<String>(entry.recordId)],
    ).getSingleOrNull();
    if (existing != null) return;
    final columns = <String, Object?>{
      'id': entry.recordId,
      'created_at': Hlc.parse(entry.hlc).millis,
      'created_by': entry.originDevice,
      'updated_hlc': entry.hlc,
      'updated_by': entry.originDevice,
      ...schema.insertDefaults,
    };
    await _db.customInsert(
      'INSERT INTO ${schema.table} (${columns.keys.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      variables: [for (final value in columns.values) _variable(value)],
      updates: {schema.tableOf(_db)},
    );
  }

  Future<void> _applyGroup(
    EntitySchema schema,
    SyncEntry entry,
    String group,
    String? prev,
    Map<String, dynamic> values,
  ) async {
    final clockQuery = _db.select(_db.rowClocks)
      ..where(
        (clock) =>
            clock.entity.equals(entry.entity) &
            clock.recordId.equals(entry.recordId) &
            clock.fieldGroup.equals(group),
      );
    final localHlc = (await clockQuery.getSingleOrNull())?.hlc;
    if (localHlc == entry.hlc) return;
    final incomingWins = localHlc == null || entry.hlc.compareTo(localHlc) > 0;
    final concurrent = localHlc != null && prev != localHlc;

    if (group == deletedFieldGroup) {
      if (incomingWins) {
        await _db.customUpdate(
          'UPDATE ${schema.table} SET deleted_hlc = ? WHERE id = ?',
          variables: [Variable<String>(entry.hlc), Variable<String>(entry.recordId)],
          updates: {schema.tableOf(_db)},
        );
        await _setClock(entry, group);
      }
      return;
    }

    final columns = schema.groups[group];
    if (columns == null) return;
    final incoming = <String, Object?>{
      for (final column in columns)
        if (values.containsKey(column)) column: _normalize(values[column]),
    };
    if (incoming.isEmpty) return;
    final current = await _readColumns(schema, entry.recordId, incoming.keys.toList());
    final differs = !_sameValues(current, incoming);

    if (incomingWins) {
      if (concurrent && differs) {
        await _recordConflict(entry, group, current, localHlc!, entry.hlc);
      }
      if (differs) await _writeColumns(schema, entry.recordId, incoming);
      await _setClock(entry, group);
    } else if (concurrent && differs) {
      await _recordConflict(entry, group, incoming, entry.hlc, localHlc!);
    }
  }

  Future<Map<String, Object?>> _readColumns(
    EntitySchema schema,
    String recordId,
    List<String> columns,
  ) async {
    final row = await _db.customSelect(
      'SELECT ${columns.join(', ')} FROM ${schema.table} WHERE id = ?',
      variables: [Variable<String>(recordId)],
    ).getSingleOrNull();
    if (row == null) return const {};
    return {for (final column in columns) column: _normalize(row.data[column])};
  }

  Future<void> _writeColumns(
    EntitySchema schema,
    String recordId,
    Map<String, Object?> values,
  ) async {
    final assignments = values.keys.map((column) => '$column = ?').join(', ');
    await _db.customUpdate(
      'UPDATE ${schema.table} SET $assignments WHERE id = ?',
      variables: [
        for (final value in values.values) _variable(value),
        Variable<String>(recordId),
      ],
      updates: {schema.tableOf(_db)},
    );
  }

  Future<void> _setClock(SyncEntry entry, String group) async {
    await _db.into(_db.rowClocks).insertOnConflictUpdate(
          RowClocksCompanion.insert(
            entity: entry.entity,
            recordId: entry.recordId,
            fieldGroup: group,
            hlc: entry.hlc,
            device: entry.originDevice,
          ),
        );
  }

  Future<void> _recordConflict(
    SyncEntry entry,
    String group,
    Map<String, Object?> losingValues,
    String losingHlc,
    String winningHlc,
  ) async {
    final id = Ids.deterministic(
      'conflict',
      '${entry.entity}|${entry.recordId}|$group|$losingHlc|$winningHlc',
    );
    await _db.into(_db.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: id,
            entity: entry.entity,
            recordId: entry.recordId,
            fieldGroup: group,
            losingValues: jsonEncode(losingValues),
            losingHlc: losingHlc,
            winningHlc: winningHlc,
            createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  static Object? _normalize(Object? value) => value is bool ? (value ? 1 : 0) : value;

  static bool _sameValues(Map<String, Object?> current, Map<String, Object?> incoming) {
    for (final MapEntry(:key, :value) in incoming.entries) {
      if (current[key] != value) return false;
    }
    return true;
  }

  static Variable<Object> _variable(Object? value) => switch (value) {
        null => const Variable<String>(null),
        final bool flag => Variable<bool>(flag),
        final int number => Variable<int>(number),
        final double number => Variable<double>(number),
        final String text => Variable<String>(text),
        _ => throw ArgumentError.value(value, 'value', 'Nicht unterstützter Typ'),
      };
}
