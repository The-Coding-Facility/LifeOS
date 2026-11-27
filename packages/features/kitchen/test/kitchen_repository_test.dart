import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

void main() {
  late LifeosDatabase db;
  late IngredientRepository ingredients;
  late RecipeRepository recipes;
  late ShoppingRepository shopping;
  late FinanceRepository finance;
  late ChangeRecorder recorder;
  final today = DateTime(2026, 11, 27);

  setUp(() async {
    db = LifeosDatabase(NativeDatabase.memory());
    recorder = await ChangeRecorder.open(db);
    ingredients = IngredientRepository(db, recorder);
    recipes = RecipeRepository(db, recorder);
    finance = FinanceRepository(db, recorder, clock: () => today);
    shopping = ShoppingRepository(db, recorder, finance, clock: () => today);
  });

  tearDown(() => db.close());

  Future<Map<String, Ingredient>> ingredientMap() async =>
      {for (final i in await ingredients.watchAll().first) i.id: i};

  test('Zutat mit gleichem Namen wird nicht doppelt angelegt', () async {
    final first = await ingredients.create(name: 'Vollmilch', unit: IngredientUnit.milliliter, kcal: 64);
    final again = await ingredients.create(name: ' vollmilch ', unit: IngredientUnit.gram, kcal: 1);
    expect(again, first);
    final all = await ingredients.watchAll().first;
    expect(all.single.unit, IngredientUnit.milliliter);
    expect(all.single.kcal, 64);
  });

  test('Rezept speichern, laden und ändern', () async {
    final milk = await ingredients.create(name: 'Vollmilch', unit: IngredientUnit.milliliter, kcal: 64);
    final id = await recipes.create(
      RecipeDraft(
        title: 'Pfannkuchen',
        minutes: 25,
        servings: 2,
        tagIds: const ['fruehstueck'],
        ingredients: [RecipeIngredient(ingredientId: milk, amount: 250)],
        preparation: 'Alles verrühren.',
      ),
    );
    var recipe = (await recipes.watchAll().first).single;
    expect(recipe.id, id);
    expect(recipe.ingredients.single.amount, 250);
    expect(recipe.tagIds, ['fruehstueck']);
    expect(recipeNutrition(recipe, await ingredientMap()).kcal, closeTo(160, 0.001));

    await ingredients.update(milk, kcal: 48);
    expect(recipeNutrition(recipe, await ingredientMap()).kcal, closeTo(120, 0.001),
        reason: 'Rezeptwerte folgen der Zutat');

    await recipes.update(id, RecipeDraft.fromRecipe(recipe).copyWith(servings: 4));
    recipe = (await recipes.watchAll().first).single;
    expect(recipe.servings, 4);
  });

  test('Rezept zweimal in den Wagen: Mengen werden addiert', () async {
    final milk = await ingredients.create(name: 'Vollmilch', unit: IngredientUnit.milliliter);
    final eggs = await ingredients.create(name: 'Ei', unit: IngredientUnit.piece);
    final id = await recipes.create(
      RecipeDraft(
        title: 'Pfannkuchen',
        ingredients: [
          RecipeIngredient(ingredientId: milk, amount: 250),
          RecipeIngredient(ingredientId: eggs, amount: 2),
        ],
      ),
    );
    final recipe = (await recipes.watchAll().first).singleWhere((r) => r.id == id);
    await shopping.addRecipe(recipe, await ingredientMap());
    await shopping.addRecipe(recipe, await ingredientMap());
    final items = await shopping.watchAll().first;
    expect(items, hasLength(2));
    expect(items.firstWhere((i) => i.name == 'Vollmilch').amount, 500);
    expect(items.firstWhere((i) => i.name == 'Ei').amount, 4);
  });

  test('abgehakte Menge wird nicht weiter aufgestockt', () async {
    final milk = await ingredients.create(name: 'Vollmilch', unit: IngredientUnit.milliliter);
    final recipe = Recipe(id: 'r', title: 'Milch', ingredients: [RecipeIngredient(ingredientId: milk, amount: 100)]);
    await shopping.addRecipe(recipe, await ingredientMap());
    final first = (await shopping.watchAll().first).single;
    await shopping.setChecked(first.id, true);
    await shopping.addRecipe(recipe, await ingredientMap());
    expect(await shopping.watchAll().first, hasLength(2));
  });

  test('Gekauft bucht die Ausgabe mit Tag und entfernt nur abgehakte Einträge', () async {
    final carrots = await shopping.addManual('Möhren', amount: 3, unit: IngredientUnit.piece);
    final milk = await shopping.addManual('Vollmilch');
    await shopping.addManual('Klopapier');
    await shopping.setChecked(carrots, true);
    await shopping.setChecked(milk, true);

    final entryId = await shopping.checkout(totalCents: 500, tagIds: const ['essen']);
    expect(entryId, isNotNull);

    final remaining = await shopping.watchAll().first;
    expect(remaining.single.name, 'Klopapier');
    final entry = (await finance.watchEntries().first).single;
    expect(entry.kind, EntryKind.expense);
    expect(entry.amountCents, 500);
    expect(entry.tagIds, ['essen']);
    expect(entry.title, 'Einkauf: Möhren, Vollmilch');
    expect(entry.date, today);
  });

  test('Gekauft ohne Haken bucht nichts', () async {
    await shopping.addManual('Brot');
    expect(await shopping.checkout(totalCents: 300), isNull);
    expect(await finance.watchEntries().first, isEmpty);
  });

  test('langer Einkauf ergibt einen kurzen Buchungstitel', () {
    final title = ShoppingRepository.purchaseTitle([for (var i = 0; i < 40; i++) 'Artikel $i']);
    expect(title.length, ShoppingRepository.maxTitleLength);
    expect(title.endsWith('…'), isTrue);
  });

  test('zwei Geräte legen dieselbe Zutat an und haben danach eine', () async {
    final other = LifeosDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final recorderA = recorder;
    final recorderB = await ChangeRecorder.open(other);
    final onB = IngredientRepository(other, recorderB);
    await ingredients.create(name: 'Mehl', unit: IngredientUnit.gram, kcal: 348);
    await onB.create(name: 'mehl', unit: IngredientUnit.gram, kcal: 350);
    final engineA = SyncEngine(db, recorderA);
    final engineB = SyncEngine(other, recorderB);
    await engineB.applyEntries(await engineA.entriesMissingFrom(await engineB.versionVector()));
    await engineA.applyEntries(await engineB.entriesMissingFrom(await engineA.versionVector()));
    expect(await ingredients.watchAll().first, hasLength(1));
    expect(await onB.watchAll().first, hasLength(1));
    expect((await ingredients.watchAll().first).single.kcal, (await onB.watchAll().first).single.kcal);
  });
}
