import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ingredient_repository.dart';
import 'model.dart';
import 'recipe_repository.dart';
import 'shopping_repository.dart';

/// Werden in `main()` mit den echten Instanzen überschrieben.
final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => throw UnimplementedError('ingredientRepositoryProvider muss in main() überschrieben werden.'),
);
final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => throw UnimplementedError('recipeRepositoryProvider muss in main() überschrieben werden.'),
);
final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => throw UnimplementedError('shoppingRepositoryProvider muss in main() überschrieben werden.'),
);

/// Alle Zutaten, nach Namen sortiert.
final ingredientsProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref.watch(ingredientRepositoryProvider).watchAll(),
);

/// Alle Rezepte, nach Titel sortiert.
final recipesProvider = StreamProvider<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchAll(),
);

/// Die Einkaufsliste, offene Einträge zuerst.
final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>(
  (ref) => ref.watch(shoppingRepositoryProvider).watchAll(),
);
