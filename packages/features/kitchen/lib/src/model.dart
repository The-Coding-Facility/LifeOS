/// Mengeneinheit einer Zutat. Nährwerte gelten je 100 g, je 100 ml oder
/// je Stück.
enum IngredientUnit {
  gram('g', 'g', 'je 100 g'),
  milliliter('ml', 'ml', 'je 100 ml'),
  piece('piece', 'Stück', 'je Stück');

  const IngredientUnit(this.key, this.label, this.perLabel);

  final String key;
  final String label;
  final String perLabel;

  static IngredientUnit fromKey(String? key) =>
      values.firstWhere((unit) => unit.key == key, orElse: () => IngredientUnit.gram);

  static IngredientUnit? tryFromKey(String? key) {
    for (final unit in values) {
      if (unit.key == key) return unit;
    }
    return null;
  }
}

/// Eine Zutat mit Nährwerten (je 100 g/ml bzw. je Stück).
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    this.unit = IngredientUnit.gram,
    this.kcal = 0,
    this.protein = 0,
    this.fat = 0,
  });

  final String id;
  final String name;
  final IngredientUnit unit;
  final double kcal;
  final double protein;
  final double fat;
}

/// Eine Zutat mit Menge in einem Rezept.
class RecipeIngredient {
  const RecipeIngredient({required this.ingredientId, required this.amount});

  final String ingredientId;

  /// In der Einheit der Zutat (g, ml oder Stück).
  final double amount;

  Map<String, Object?> toJson() => {'id': ingredientId, 'amount': amount};

  static RecipeIngredient? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final amount = json['amount'];
    if (id is! String || amount is! num) return null;
    return RecipeIngredient(ingredientId: id, amount: amount.toDouble());
  }
}

/// Ein Rezept. Nährwerte werden aus den Zutaten berechnet.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.minutes,
    this.servings = 1,
    this.tagIds = const [],
    this.ingredients = const [],
    this.preparation = '',
  });

  final String id;
  final String title;

  /// Zubereitungszeit in Minuten.
  final int? minutes;
  final int servings;
  final List<String> tagIds;
  final List<RecipeIngredient> ingredients;
  final String preparation;
}

/// Formularwerte eines Rezepts.
class RecipeDraft {
  const RecipeDraft({
    required this.title,
    this.minutes,
    this.servings = 1,
    this.tagIds = const [],
    this.ingredients = const [],
    this.preparation = '',
  });

  factory RecipeDraft.fromRecipe(Recipe recipe) => RecipeDraft(
        title: recipe.title,
        minutes: recipe.minutes,
        servings: recipe.servings,
        tagIds: recipe.tagIds,
        ingredients: recipe.ingredients,
        preparation: recipe.preparation,
      );

  final String title;
  final int? minutes;
  final int servings;
  final List<String> tagIds;
  final List<RecipeIngredient> ingredients;
  final String preparation;

  RecipeDraft copyWith({
    String? title,
    int? minutes,
    int? servings,
    List<String>? tagIds,
    List<RecipeIngredient>? ingredients,
    String? preparation,
  }) {
    return RecipeDraft(
      title: title ?? this.title,
      minutes: minutes ?? this.minutes,
      servings: servings ?? this.servings,
      tagIds: tagIds ?? this.tagIds,
      ingredients: ingredients ?? this.ingredients,
      preparation: preparation ?? this.preparation,
    );
  }
}

/// Ein Eintrag der Einkaufsliste.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.amount,
    this.unit,
    this.ingredientId,
    this.recipeId,
    this.checked = false,
  });

  final String id;
  final String name;
  final double? amount;
  final IngredientUnit? unit;
  final String? ingredientId;
  final String? recipeId;
  final bool checked;
}
