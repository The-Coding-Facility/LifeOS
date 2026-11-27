import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';

void main() {
  const milk = Ingredient(id: 'milch', name: 'Vollmilch', unit: IngredientUnit.milliliter, kcal: 64, protein: 3.4, fat: 3.6);
  const egg = Ingredient(id: 'ei', name: 'Ei', unit: IngredientUnit.piece, kcal: 80, protein: 7, fat: 5.5);

  test('Nährwerte je 100 ml und je Stück', () {
    final fromMilk = nutritionOf(milk, 250);
    expect(fromMilk.kcal, closeTo(160, 0.001));
    expect(fromMilk.protein, closeTo(8.5, 0.001));
    final fromEggs = nutritionOf(egg, 2);
    expect(fromEggs.kcal, 160);
    expect(fromEggs.fat, 11);
  });

  test('Rezept gesamt und pro Portion, gelöschte Zutat zählt nicht', () {
    const recipe = Recipe(
      id: 'r',
      title: 'Pfannkuchen',
      servings: 2,
      ingredients: [
        RecipeIngredient(ingredientId: 'milch', amount: 250),
        RecipeIngredient(ingredientId: 'ei', amount: 2),
        RecipeIngredient(ingredientId: 'gibt-es-nicht', amount: 100),
      ],
    );
    final total = recipeNutrition(recipe, {'milch': milk, 'ei': egg});
    expect(total.kcal, closeTo(320, 0.001));
    expect(perServing(total, 2).kcal, closeTo(160, 0.001));
    expect(perServing(total, 0).kcal, closeTo(320, 0.001));
    expect(total.describe(), '320 kcal · 22,5 g Protein · 20 g Fett');
  });

  test('Mengen lesen und anzeigen', () {
    expect(parseAmount('1,5'), 1.5);
    expect(parseAmount('1.5'), 1.5);
    expect(parseAmount(' 250 '), 250);
    expect(parseAmount(''), isNull);
    expect(parseAmount('-2'), isNull);
    expect(parseAmount('etwas'), isNull);
    expect(formatAmount(1.5), '1,5');
    expect(formatAmount(250), '250');
    expect(formatAmount(0.3333), '0,33');
    expect(formatQuantity(250, IngredientUnit.gram), '250 g');
    expect(formatQuantity(1.5, IngredientUnit.piece), '1,5 Stück');
    expect(formatQuantity(null, IngredientUnit.piece), '');
  });
}
