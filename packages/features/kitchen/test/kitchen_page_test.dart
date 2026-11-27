import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

void main() {
  const milk = Ingredient(id: 'milch', name: 'Vollmilch', unit: IngredientUnit.milliliter, kcal: 64);
  const recipe = Recipe(
    id: 'r',
    title: 'Pfannkuchen',
    minutes: 25,
    servings: 2,
    tagIds: ['fruehstueck'],
    ingredients: [RecipeIngredient(ingredientId: 'milch', amount: 500)],
  );

  Widget host({int tab = 0}) => ProviderScope(
        overrides: [
          recipesProvider.overrideWith((ref) => Stream.value(const [recipe])),
          ingredientsProvider.overrideWith((ref) => Stream.value(const [milk])),
          shoppingItemsProvider.overrideWith(
            (ref) => Stream.value(const [
              ShoppingItem(id: 'a', name: 'Möhren', amount: 3, unit: IngredientUnit.piece, checked: true),
              ShoppingItem(id: 'b', name: 'Klopapier'),
            ]),
          ),
          tagsProvider.overrideWith(
            (ref, scope) => Stream.value(const [
              TagItem(id: 'fruehstueck', scope: TagScope.recipes, name: 'Frühstück'),
            ]),
          ),
        ],
        child: MaterialApp(theme: buildLifeosTheme(Brightness.light), home: KitchenPage(initialTab: tab)),
      );

  testWidgets('Rezeptliste zeigt Zeit und kcal pro Portion', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Pfannkuchen'), findsOneWidget);
    expect(find.text('25 Min · 160 kcal pro Portion · Frühstück'), findsOneWidget);
  });

  testWidgets('Einkaufsliste zeigt Mengen und den Gekauft-Knopf', (tester) async {
    await tester.pumpWidget(host(tab: 1));
    await tester.pumpAndSettle();
    expect(find.text('Möhren'), findsOneWidget);
    expect(find.text('3 Stück'), findsOneWidget);
    expect(find.text('Gekauft (1)'), findsOneWidget);
  });
}
