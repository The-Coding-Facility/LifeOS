import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'tag_item.dart';

/// Lesen und Schreiben von Tags. Jede Änderung wird protokolliert.
///
/// Die ID eines Tags entsteht aus Bereich und normalisiertem Namen. Legen
/// zwei Geräte offline „Sport“ an, wird daraus nach dem Sync ein Tag.
/// Feldgruppen: `scope`, `name`, `color`, `limit`.
class TagRepository {
  TagRepository(this._db, this._recorder);

  static const String entity = 'tags';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// ID, die ein Tag mit diesem Namen bekommt.
  static String idFor(TagScope scope, String name) =>
      Ids.deterministic('tag:${scope.key}', Ids.normalizeName(name));

  Stream<List<TagItem>> watch(TagScope scope) {
    final query = _db.select(_db.tags)
      ..where((tag) => tag.scope.equals(scope.key) & tag.deletedHlc.isNull());
    return query.watch().map((rows) {
      final items = [for (final row in rows) _toItem(row)];
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  /// Legt einen Tag an oder gibt den vorhandenen mit gleichem Namen zurück.
  /// Ein gelöschter Tag mit gleichem Namen wird wiederbelebt.
  Future<String> create(
    TagScope scope,
    String name, {
    int? colorIndex,
    int? monthlyLimitCents,
  }) {
    final cleanName = _requireName(name);
    return _db.transaction(() async {
      final id = idFor(scope, cleanName);
      final existing = await (_db.select(_db.tags)..where((tag) => tag.id.equals(id))).getSingleOrNull();
      if (existing != null && existing.deletedHlc == null) return id;

      final color = colorIndex ?? await _nextColor(scope);
      final groups = <String, Map<String, Object?>>{
        'scope': {'scope': scope.key},
        'name': {'name': cleanName},
        'color': {'color_index': color},
        'limit': {'monthly_limit_cents': monthlyLimitCents},
      };
      if (existing != null) {
        // Wiederbeleben: Die Löschung ist eine eigene Feldgruppe und wird
        // mit einem neueren Zeitstempel aufgehoben.
        groups[deletedFieldGroup] = {'deleted': false};
      }
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: groups,
      );
      if (existing == null) {
        await _db.into(_db.tags).insert(
              TagsCompanion.insert(
                id: id,
                scope: scope.key,
                name: cleanName,
                colorIndex: Value(color),
                monthlyLimitCents: Value(monthlyLimitCents),
                createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
                createdBy: _recorder.deviceId,
                updatedHlc: hlc.pack(),
                updatedBy: _recorder.deviceId,
              ),
            );
      } else {
        await (_db.update(_db.tags)..where((tag) => tag.id.equals(id))).write(
          TagsCompanion(
            name: Value(cleanName),
            colorIndex: Value(color),
            monthlyLimitCents: Value(monthlyLimitCents),
            deletedHlc: const Value(null),
            updatedHlc: Value(hlc.pack()),
            updatedBy: Value(_recorder.deviceId),
          ),
        );
      }
      return id;
    });
  }

  /// Ändert Name, Farbe oder Budget. Die ID bleibt beim Umbenennen gleich.
  Future<void> update(
    String id, {
    String? name,
    int? colorIndex,
    int? monthlyLimitCents,
    bool clearLimit = false,
  }) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final groups = <String, Map<String, Object?>>{};
      if (name != null) {
        final cleanName = _requireName(name);
        if (cleanName != current.name) groups['name'] = {'name': cleanName};
      }
      if (colorIndex != null && colorIndex != current.colorIndex) {
        groups['color'] = {'color_index': colorIndex};
      }
      final newLimit = clearLimit ? null : (monthlyLimitCents ?? current.monthlyLimitCents);
      if (newLimit != current.monthlyLimitCents) {
        groups['limit'] = {'monthly_limit_cents': newLimit};
      }
      if (groups.isEmpty) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: groups,
      );
      await (_db.update(_db.tags)..where((tag) => tag.id.equals(id))).write(
        TagsCompanion(
          name: groups.containsKey('name') ? Value(groups['name']!['name']! as String) : const Value.absent(),
          colorIndex: groups.containsKey('color') ? Value(colorIndex!) : const Value.absent(),
          monthlyLimitCents: groups.containsKey('limit') ? Value(newLimit) : const Value.absent(),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Löscht einen Tag als Tombstone. Termine und Buchungen behalten die ID,
  /// zeigen den Tag aber nicht mehr an.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await (_db.update(_db.tags)..where((tag) => tag.id.equals(id))).write(
        TagsCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  Future<TagRow?> _findActive(String id) {
    final query = _db.select(_db.tags)..where((tag) => tag.id.equals(id) & tag.deletedHlc.isNull());
    return query.getSingleOrNull();
  }

  Future<int> _nextColor(TagScope scope) async {
    final rows = await (_db.select(_db.tags)..where((tag) => tag.scope.equals(scope.key))).get();
    return rows.length;
  }

  static String _requireName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw ArgumentError('Ein Tag braucht einen Namen.');
    }
    return trimmed;
  }

  static TagItem _toItem(TagRow row) => TagItem(
        id: row.id,
        scope: TagScope.values.firstWhere(
          (scope) => scope.key == row.scope,
          orElse: () => TagScope.calendar,
        ),
        name: row.name,
        colorIndex: row.colorIndex,
        monthlyLimitCents: row.monthlyLimitCents,
      );
}
