import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';
import 'recipe_editor_page.dart';
import 'recipes_tab.dart';

/// Alle Details eines Rezepts.
class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${recipe.title}“ löschen?'),
        content: const Text('Das Rezept wird auf allen Geräten gelöscht. Zutaten bleiben erhalten.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recipeRepositoryProvider).delete(recipe.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipe = (ref.watch(recipesProvider).value ?? const <Recipe>[]).where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.menu_book_outlined, message: 'Dieses Rezept gibt es nicht mehr.'));
    }
    final ingredients = {
      for (final ingredient in ref.watch(ingredientsProvider).value ?? const <Ingredient>[]) ingredient.id: ingredient,
    };
    final tags = {
      for (final tag in ref.watch(tagsProvider(TagScope.recipes)).value ?? const <TagItem>[]) tag.id: tag,
    };
    final total = recipeNutrition(recipe, ingredients);
    final portion = perServing(total, recipe.servings);

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: 'Auf die Einkaufsliste',
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () => addRecipeToShoppingList(context, ref, recipe),
          ),
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openRecipeEditor(context, recipe: recipe),
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, recipe),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (recipe.minutes != null)
                Chip(avatar: const Icon(Icons.timer_outlined, size: 18), label: Text('${recipe.minutes} Min')),
              Chip(
                avatar: const Icon(Icons.people_outline, size: 18),
                label: Text(recipe.servings == 1 ? '1 Portion' : '${recipe.servings} Portionen'),
              ),
              for (final id in recipe.tagIds)
                if (tags[id] != null)
                  Chip(
                    avatar: CircleAvatar(radius: 6, backgroundColor: tagColor(tags[id]!.colorIndex)),
                    label: Text(tags[id]!.name),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Nährwerte',
            icon: Icons.local_fire_department_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pro Portion: ${portion.describe()}', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('Gesamt: ${total.describe()}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Zutaten', style: theme.textTheme.titleMedium),
          if (recipe.ingredients.isEmpty) const Text('Noch keine Zutaten.'),
          for (final item in recipe.ingredients)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 80,
                child: Text(
                  formatQuantity(item.amount, ingredients[item.ingredientId]?.unit),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              title: Text(ingredients[item.ingredientId]?.name ?? 'Gelöschte Zutat'),
            ),
          const SizedBox(height: 16),
          Text('Zubereitung', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(recipe.preparation.isEmpty ? 'Keine Beschreibung.' : recipe.preparation),
        ],
      ),
    );
  }
}
