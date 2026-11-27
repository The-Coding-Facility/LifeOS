import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Die Einkaufsliste.
///
/// Feldgruppen: `item` (Name, Menge, Einheit, Zutat), `source` (Rezept),
/// `checked`. „Gekauft“ bucht über [FinanceRepository] eine Ausgabe und
/// entfernt die abgehakten Einträge in derselben Transaktion.
class ShoppingRepository {
  ShoppingRepository(this._db, this._recorder, this._finance, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const String entity = 'shopping_items';

  /// Höchstlänge des Buchungstitels „Einkauf: …“.
  static const int maxTitleLength = 120;

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;
  final FinanceRepository _finance;
  final DateTime Function() _clock;

  /// Offene Einträge zuerst, dann abgehakte; jeweils in der Reihenfolge des
  /// Anlegens.
  Stream<List<ShoppingItem>> watchAll() {
    final query = _db.select(_db.shoppingItems)
      ..where((item) => item.deletedHlc.isNull())
      ..orderBy([
        (item) => OrderingTerm.asc(item.checked),
        (item) => OrderingTerm.asc(item.createdAt),
      ]);
    return query.watch().map((rows) => [for (final row in rows) _toItem(row)]);
  }

  /// Fügt einen Eintrag von Hand hinzu.
  Future<String> addManual(String name, {double? amount, IngredientUnit? unit}) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Ein Eintrag braucht einen Namen.');
    return _db.transaction(
      () => _insert(name: cleanName, amount: amount, unit: unit, ingredientId: null, recipeId: null),
    );
  }

  /// Setzt alle Zutaten von [recipe] auf die Liste. Steht eine Zutat in
  /// derselben Einheit schon offen auf der Liste, wird die Menge addiert.
  /// Gibt die Zahl der betroffenen Einträge zurück.
  Future<int> addRecipe(Recipe recipe, Map<String, Ingredient> ingredients) {
    return _db.transaction(() async {
      var count = 0;
      for (final item in recipe.ingredients) {
        final ingredient = ingredients[item.ingredientId];
        if (ingredient == null) continue;
        final open = await (_db.select(_db.shoppingItems)
              ..where(
                (row) =>
                    row.deletedHlc.isNull() &
                    row.checked.equals(false) &
                    row.ingredientId.equals(ingredient.id) &
                    row.unit.equals(ingredient.unit.key),
              ))
            .get();
        if (open.isNotEmpty) {
          final existing = open.first;
          final amount = (existing.amount ?? 0) + item.amount;
          final hlc = await _recorder.record(
            entity: entity,
            recordId: existing.id,
            op: ChangeOp.upsert,
            groups: {
              'item': {
                'name': existing.name,
                'amount': amount,
                'unit': existing.unit,
                'ingredient_id': existing.ingredientId,
              },
            },
          );
          await (_db.update(_db.shoppingItems)..where((row) => row.id.equals(existing.id))).write(
            ShoppingItemsCompanion(
              amount: Value(amount),
              updatedHlc: Value(hlc.pack()),
              updatedBy: Value(_recorder.deviceId),
            ),
          );
        } else {
          await _insert(
            name: ingredient.name,
            amount: item.amount,
            unit: ingredient.unit,
            ingredientId: ingredient.id,
            recipeId: recipe.id,
          );
        }
        count++;
      }
      return count;
    });
  }

  Future<void> setChecked(String id, bool checked) {
    return _db.transaction(() async {
      final row = await _findActive(id);
      if (row == null || row.checked == checked) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.upsert,
        groups: {
          'checked': {'checked': checked},
        },
      );
      await (_db.update(_db.shoppingItems)..where((item) => item.id.equals(id))).write(
        ShoppingItemsCompanion(
          checked: Value(checked),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  /// Entfernt einen Eintrag (Tombstone).
  Future<void> remove(String id) => _db.transaction(() => _tombstone(id));

  /// „Gekauft“: bucht eine Ausgabe über [totalCents] mit [tagIds] und
  /// entfernt alle abgehakten Einträge. Gibt die ID der Buchung zurück oder
  /// `null`, wenn nichts abgehakt war.
  Future<String?> checkout({required int totalCents, List<String> tagIds = const [], DateTime? date}) {
    return _db.transaction(() async {
      final checked = await (_db.select(_db.shoppingItems)
            ..where((item) => item.deletedHlc.isNull() & item.checked.equals(true))
            ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]))
          .get();
      if (checked.isEmpty) return null;
      final entryId = await _finance.addEntry(
        EntryDraft(
          kind: EntryKind.expense,
          amountCents: totalCents,
          date: date ?? _clock(),
          title: purchaseTitle([for (final row in checked) row.name]),
          tagIds: tagIds,
        ),
      );
      for (final row in checked) {
        await _tombstone(row.id);
      }
      return entryId;
    });
  }

  /// „Einkauf: Möhren, Vollmilch“, gekürzt auf [maxTitleLength] Zeichen.
  static String purchaseTitle(List<String> names) {
    final title = 'Einkauf: ${names.join(', ')}';
    if (title.length <= maxTitleLength) return title;
    return '${title.substring(0, maxTitleLength - 1).trimRight()}…';
  }

  Future<String> _insert({
    required String name,
    required double? amount,
    required IngredientUnit? unit,
    required String? ingredientId,
    required String? recipeId,
  }) async {
    final id = Ids.newId();
    final hlc = await _recorder.record(
      entity: entity,
      recordId: id,
      op: ChangeOp.upsert,
      groups: {
        'item': {'name': name, 'amount': amount, 'unit': unit?.key, 'ingredient_id': ingredientId},
        'source': {'recipe_id': recipeId},
        'checked': {'checked': false},
      },
    );
    await _db.into(_db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(
            id: id,
            name: name,
            amount: Value(amount),
            unit: Value(unit?.key),
            ingredientId: Value(ingredientId),
            recipeId: Value(recipeId),
            createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            createdBy: _recorder.deviceId,
            updatedHlc: hlc.pack(),
            updatedBy: _recorder.deviceId,
          ),
        );
    return id;
  }

  Future<void> _tombstone(String id) async {
    final row = await _findActive(id);
    if (row == null) return;
    final hlc = await _recorder.record(
      entity: entity,
      recordId: id,
      op: ChangeOp.delete,
      groups: {
        deletedFieldGroup: {'deleted': true},
      },
    );
    await (_db.update(_db.shoppingItems)..where((item) => item.id.equals(id))).write(
      ShoppingItemsCompanion(
        deletedHlc: Value(hlc.pack()),
        updatedHlc: Value(hlc.pack()),
        updatedBy: Value(_recorder.deviceId),
      ),
    );
  }

  Future<ShoppingItemRow?> _findActive(String id) =>
      (_db.select(_db.shoppingItems)..where((item) => item.id.equals(id) & item.deletedHlc.isNull()))
          .getSingleOrNull();

  static ShoppingItem _toItem(ShoppingItemRow row) => ShoppingItem(
        id: row.id,
        name: row.name,
        amount: row.amount,
        unit: IngredientUnit.tryFromKey(row.unit),
        ingredientId: row.ingredientId,
        recipeId: row.recipeId,
        checked: row.checked,
      );
}
