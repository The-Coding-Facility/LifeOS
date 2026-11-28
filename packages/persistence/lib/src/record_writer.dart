import 'package:drift/drift.dart';

import 'change_recorder.dart';
import 'database.dart';

/// Schreibt synchronisierte Zeilen und protokolliert sie im selben Schritt.
///
/// Für Tabellen mit [SyncColumns]: legt Zeilen an, ändert Spalten oder
/// löscht als Tombstone, jeweils mit passendem Eintrag im Änderungsprotokoll.
/// Spaltennamen sind die SQL-Namen (z. B. `area_id`). Aufrufer laufen in
/// einer Transaktion, damit Protokoll und Zeile gemeinsam gelingen.
class RecordWriter {
  RecordWriter(this._db, this._recorder);

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  String get deviceId => _recorder.deviceId;

  /// Je Feldgruppe die Werte aus [columns].
  static Map<String, Map<String, Object?>> allGroups(
    Map<String, List<String>> groups,
    Map<String, Object?> columns,
  ) =>
      {
        for (final MapEntry(key: group, value: names) in groups.entries)
          group: {for (final name in names) name: columns[name]},
      };

  /// Nur die Feldgruppen, in denen sich [wanted] von [existing] unterscheidet.
  static Map<String, Map<String, Object?>> changedGroups(
    Map<String, List<String>> groups,
    Map<String, Object?> wanted,
    Map<String, Object?> existing,
  ) =>
      {
        for (final MapEntry(key: group, value: names) in groups.entries)
          if (names.any((name) => wanted[name] != existing[name]))
            group: {for (final name in names) name: wanted[name]},
      };

  /// Legt die Zeile [id] in [entity] an. [groups] werden protokolliert und
  /// zusammen mit [extra] (nicht synchronisierte Pflichtspalten) geschrieben.
  Future<void> insert(
    String entity,
    TableInfo<Table, Object?> table,
    String id,
    Map<String, Map<String, Object?>> groups, {
    Map<String, Object?> extra = const {},
  }) async {
    final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
    final columns = <String, Object?>{
      'id': id,
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'created_by': deviceId,
      'updated_hlc': hlc.pack(),
      'updated_by': deviceId,
      for (final group in groups.values) ...group,
      ...extra,
    };
    await _db.customInsert(
      'INSERT INTO $entity (${columns.keys.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      variables: [for (final value in columns.values) variableOf(value)],
      updates: {table},
    );
  }

  /// Protokolliert [groups] für [id] und schreibt ihre Spalten.
  Future<void> update(
    String entity,
    TableInfo<Table, Object?> table,
    String id,
    Map<String, Map<String, Object?>> groups,
  ) async {
    if (groups.isEmpty) return;
    final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
    final values = {for (final group in groups.values) ...group};
    final assignments = [
      for (final column in values.keys)
        if (column != deletedFieldGroup) '$column = ?',
      'updated_hlc = ?',
      'updated_by = ?',
    ];
    await _db.customUpdate(
      'UPDATE $entity SET ${assignments.join(', ')} WHERE id = ?',
      variables: [
        for (final MapEntry(:key, :value) in values.entries)
          if (key != deletedFieldGroup) variableOf(value),
        Variable<String>(hlc.pack()),
        Variable<String>(deviceId),
        Variable<String>(id),
      ],
      updates: {table},
    );
  }

  /// Löscht [id] als Tombstone, falls die Zeile noch aktiv ist.
  Future<bool> delete(String entity, TableInfo<Table, Object?> table, String id) async {
    final present = await _db.customSelect(
      'SELECT 1 AS present FROM $entity WHERE id = ? AND deleted_hlc IS NULL',
      variables: [Variable<String>(id)],
    ).getSingleOrNull();
    if (present == null) return false;
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
        Variable<String>(deviceId),
        Variable<String>(id),
      ],
      updates: {table},
    );
    return true;
  }

  /// Wandelt einen Spaltenwert in eine SQL-Variable.
  static Variable<Object> variableOf(Object? value) => switch (value) {
        null => const Variable<String>(null),
        final bool flag => Variable<bool>(flag),
        final int number => Variable<int>(number),
        final double number => Variable<double>(number),
        final String text => Variable<String>(text),
        _ => throw ArgumentError.value(value, 'value', 'Nicht unterstützter Typ'),
      };
}
