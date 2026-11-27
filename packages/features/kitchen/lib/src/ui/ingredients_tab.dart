import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';
import 'ingredient_dialog.dart';

/// Reiter „Zutaten“: alle Zutaten mit Nährwerten zum Nachschlagen und Ändern.
class IngredientsTab extends ConsumerStatefulWidget {
  const IngredientsTab({super.key});

  @override
  ConsumerState<IngredientsTab> createState() => _IngredientsTabState();
}

class _IngredientsTabState extends ConsumerState<IngredientsTab> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final ingredient in ingredients)
        if (query.isEmpty || ingredient.name.toLowerCase().contains(query)) ingredient,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Zutat suchen'),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          EmptyState(
            icon: Icons.kitchen_outlined,
            message: ingredients.isEmpty
                ? 'Noch keine Zutaten. Sie entstehen auch beim Anlegen eines Rezepts.'
                : 'Keine Zutat passt zur Suche.',
          ),
        for (final ingredient in visible)
          ListTile(
            title: Text(ingredient.name),
            subtitle: Text(
              '${ingredient.unit.perLabel}: '
              '${Nutrition(kcal: ingredient.kcal, protein: ingredient.protein, fat: ingredient.fat).describe()}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => showIngredientDialog(context, ref, ingredient: ingredient),
          ),
      ],
    );
  }
}
