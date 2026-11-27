import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Zutaten-Datenbank. Die ID entsteht aus dem normalisierten Namen.
///
/// Feldgruppen: `name`, `unit`, `nutrition` (kcal, Protein, Fett).
class IngredientRepository {
  IngredientRepository(this._db, this._recorder);

  static const String entity = 'ingredients';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// ID, die eine Zutat mit diesem Namen bekommt.
  static String idFor(String name) => Ids.deterministic('ingredient', Ids.normalizeName(name));

  /// Alle Zutaten, nach Namen sortiert.
  Stream<List<Ingredient>> watchAll() {
    final query = _db.select(_db.ingredients)..where((i) => i.deletedHlc.isNull());
    return query.watch().map((rows) {
      final items = [for (final row in rows) _toIngredient(row)];
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  /// Legt eine Zutat an. Gibt es den Namen schon, bleibt die vorhandene
  /// unverändert und ihre ID wird zurückgegeben. Eine gelöschte Zutat mit
  /// gleichem Namen wird mit den neuen Werten wiederbelebt.
  Future<String> create({
    required String name,
    required IngredientUnit unit,
    double kcal = 0,
    double protein = 0,
    double fat = 0,
  }) {
    final cleanName = _requireName(name);
    return _db.transaction(() async {
      final id = idFor(cleanName);
      final row = await (_db.select(_db.ingredients)..where((i) => i.id.equals(id))).getSingleOrNull();
      if (row != null && row.deletedHlc == null) return id;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'name': {'name': cleanName},
          'unit': {'unit': unit.key},
          'nutrition': {'kcal': kcal, 'protein': protein, 'fat': fat},
          if (row != null) deletedFieldGroup: {'deleted': false},
        },
      );
      final companion = IngredientsCompanion(
        name: Value(cleanName),
        unit: Value(unit.key),
        kcal: Value(kcal),
        protein: Value(protein),
        fat: Value(fat),
        deletedHlc: const Value(null),
        updatedHlc: Value(hlc.pack()),
        updatedBy: Value(_recorder.deviceId),
      );
      if (row == null) {
        await _db.into(_db.ingredients).insert(
              companion.copyWith(
                id: Value(id),
                createdAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
                createdBy: Value(_recorder.deviceId),
              ),
            );
      } else {
        await (_db.update(_db.ingredients)..where((i) => i.id.equals(id))).write(companion);
      }
      return id;
    });
  }

  /// Ändert Name, Einheit oder Nährwerte. Die ID bleibt.
  Future<void> update(
    String id, {
    String? name,
    IngredientUnit? unit,
    double? kcal,
    double? protein,
    double? fat,
  }) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.ingredients)..where((i) => i.id.equals(id) & i.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final newName = name == null ? row.name : _requireName(name);
      final newUnit = unit?.key ?? row.unit;
      final newKcal = kcal ?? row.kcal;
      final newProtein = protein ?? row.protein;
      final newFat = fat ?? row.fat;
      final groups = <String, Map<String, Object?>>{
        if (newName != row.name) 'name': {'name': newName},
        if (newUnit != row.unit) 'unit': {'unit': newUnit},
        if (newKcal != row.kcal || newProtein != row.protein || newFat != row.fat)
          'nutrition': {'kcal': newKcal, 'protein': newProtein, 'fat': newFat},
      };
      if (groups.isEmpty) return;
      final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
      await (_db.update(_db.ingredients)..where((i) => i.id.equals(id))).write(
        IngredientsCompanion(
          name: Value(newName),
          unit: Value(newUnit),
          kcal: Value(newKcal),
          protein: Value(newProtein),
          fat: Value(newFat),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Löscht eine Zutat als Tombstone. Rezepte behalten die ID und zeigen
  /// sie als gelöscht.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.ingredients)..where((i) => i.id.equals(id) & i.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await (_db.update(_db.ingredients)..where((i) => i.id.equals(id))).write(
        IngredientsCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  static String _requireName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) throw ArgumentError('Eine Zutat braucht einen Namen.');
    return trimmed;
  }

  static Ingredient _toIngredient(IngredientRow row) => Ingredient(
        id: row.id,
        name: row.name,
        unit: IngredientUnit.fromKey(row.unit),
        kcal: row.kcal,
        protein: row.protein,
        fat: row.fat,
      );
}
