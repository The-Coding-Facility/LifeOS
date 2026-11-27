import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Lesen und Schreiben von Rezepten.
///
/// Feldgruppen: `title`, `details` (Minuten, Portionen), `tags`,
/// `ingredients` (JSON-Liste), `preparation`.
class RecipeRepository {
  RecipeRepository(this._db, this._recorder);

  static const String entity = 'recipes';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  static const Map<String, List<String>> _groups = {
    'title': ['title'],
    'details': ['minutes', 'servings'],
    'tags': ['tag_ids'],
    'ingredients': ['ingredients'],
    'preparation': ['preparation'],
  };

  /// Alle Rezepte, nach Titel sortiert.
  Stream<List<Recipe>> watchAll() {
    final query = _db.select(_db.recipes)..where((r) => r.deletedHlc.isNull());
    return query.watch().map((rows) {
      final recipes = [for (final row in rows) _toRecipe(row)];
      recipes.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return recipes;
    });
  }

  Future<String> create(RecipeDraft draft) {
    return _db.transaction(() async {
      final id = Ids.newId();
      final columns = _columnsOf(draft);
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          for (final MapEntry(key: group, value: names) in _groups.entries)
            group: {for (final name in names) name: columns[name]},
        },
      );
      await _db.into(_db.recipes).insert(
            RecipesCompanion.insert(
              id: id,
              title: columns['title']! as String,
              minutes: Value(columns['minutes'] as int?),
              servings: Value(columns['servings']! as int),
              tagIds: Value(columns['tag_ids']! as String),
              ingredients: Value(columns['ingredients']! as String),
              preparation: Value(columns['preparation']! as String),
              createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
              createdBy: _recorder.deviceId,
              updatedHlc: hlc.pack(),
              updatedBy: _recorder.deviceId,
            ),
          );
      return id;
    });
  }

  /// Speichert nur geänderte Feldgruppen.
  Future<void> update(String id, RecipeDraft draft) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.recipes)..where((r) => r.id.equals(id) & r.deletedHlc.isNull()))
          .getSingleOrNull();
      if (row == null) return;
      final wanted = _columnsOf(draft);
      final existing = <String, Object?>{
        'title': row.title,
        'minutes': row.minutes,
        'servings': row.servings,
        'tag_ids': row.tagIds,
        'ingredients': row.ingredients,
        'preparation': row.preparation,
      };
      final groups = {
        for (final MapEntry(key: group, value: names) in _groups.entries)
          if (names.any((name) => wanted[name] != existing[name]))
            group: {for (final name in names) name: wanted[name]},
      };
      if (groups.isEmpty) return;
      final hlc = await _recorder.record(entity: entity, recordId: id, op: ChangeOp.upsert, groups: groups);
      await (_db.update(_db.recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(
          title: Value(wanted['title']! as String),
          minutes: Value(wanted['minutes'] as int?),
          servings: Value(wanted['servings']! as int),
          tagIds: Value(wanted['tag_ids']! as String),
          ingredients: Value(wanted['ingredients']! as String),
          preparation: Value(wanted['preparation']! as String),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  Future<void> delete(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.recipes)..where((r) => r.id.equals(id) & r.deletedHlc.isNull()))
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
      await (_db.update(_db.recipes)..where((r) => r.id.equals(id))).write(
        RecipesCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  static Map<String, Object?> _columnsOf(RecipeDraft draft) {
    final title = draft.title.trim();
    if (title.isEmpty) throw ArgumentError('Ein Rezept braucht einen Titel.');
    return {
      'title': title,
      'minutes': draft.minutes != null && draft.minutes! > 0 ? draft.minutes : null,
      'servings': draft.servings < 1 ? 1 : draft.servings,
      'tag_ids': jsonEncode(draft.tagIds),
      'ingredients': jsonEncode([for (final item in draft.ingredients) item.toJson()]),
      'preparation': draft.preparation.trim(),
    };
  }

  static Recipe _toRecipe(RecipeRow row) {
    List<Object?> decode(String json) {
      try {
        final value = jsonDecode(json);
        return value is List ? value : const [];
      } on FormatException {
        return const [];
      }
    }

    return Recipe(
      id: row.id,
      title: row.title,
      minutes: row.minutes,
      servings: row.servings,
      tagIds: [for (final id in decode(row.tagIds)) if (id is String) id],
      ingredients: [
        for (final item in decode(row.ingredients))
          if (RecipeIngredient.fromJson(item) case final ingredient?) ingredient,
      ],
      preparation: row.preparation,
    );
  }
}
