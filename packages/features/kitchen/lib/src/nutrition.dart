import 'model.dart';

/// kcal, Protein und Fett (in Gramm).
class Nutrition {
  const Nutrition({this.kcal = 0, this.protein = 0, this.fat = 0});

  static const zero = Nutrition();

  final double kcal;
  final double protein;
  final double fat;

  Nutrition operator +(Nutrition other) =>
      Nutrition(kcal: kcal + other.kcal, protein: protein + other.protein, fat: fat + other.fat);

  Nutrition scaled(double factor) =>
      Nutrition(kcal: kcal * factor, protein: protein * factor, fat: fat * factor);

  /// `320 kcal · 12,5 g Protein · 8 g Fett`
  String describe() =>
      '${kcal.round()} kcal · ${formatAmount(protein, maxDecimals: 1)} g Protein · '
      '${formatAmount(fat, maxDecimals: 1)} g Fett';
}

/// Nährwerte von [amount] (in der Einheit der Zutat).
Nutrition nutritionOf(Ingredient ingredient, double amount) {
  final factor = ingredient.unit == IngredientUnit.piece ? amount : amount / 100;
  return Nutrition(kcal: ingredient.kcal, protein: ingredient.protein, fat: ingredient.fat).scaled(factor);
}

/// Summe aller Zutaten. Zutaten, die es nicht (mehr) gibt, zählen nicht.
Nutrition recipeNutrition(Recipe recipe, Map<String, Ingredient> ingredients) {
  var total = Nutrition.zero;
  for (final item in recipe.ingredients) {
    final ingredient = ingredients[item.ingredientId];
    if (ingredient != null) total = total + nutritionOf(ingredient, item.amount);
  }
  return total;
}

/// Nährwerte pro Portion.
Nutrition perServing(Nutrition total, int servings) => total.scaled(1 / (servings < 1 ? 1 : servings));

/// Liest eine Menge mit Komma oder Punkt: `1,5` → 1.5. Leer, negativ oder
/// ungültig → `null`.
double? parseAmount(String text) {
  final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
  return double.parse(cleaned);
}

/// `1.5` → `1,5`, `250.0` → `250`, höchstens [maxDecimals] Nachkommastellen.
String formatAmount(double amount, {int maxDecimals = 2}) {
  var text = amount.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text.replaceAll('.', ',');
}

/// `250 g`, `1,5 Stück` oder leer.
String formatQuantity(double? amount, IngredientUnit? unit) {
  if (amount == null) return '';
  return unit == null ? formatAmount(amount) : '${formatAmount(amount)} ${unit.label}';
}
