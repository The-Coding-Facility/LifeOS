import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';
import 'recipe_detail_page.dart';

/// Setzt alle Zutaten von [recipe] auf die Einkaufsliste und meldet es.
Future<void> addRecipeToShoppingList(BuildContext context, WidgetRef ref, Recipe recipe) async {
  final ingredients = {
    for (final ingredient in ref.read(ingredientsProvider).value ?? const <Ingredient>[]) ingredient.id: ingredient,
  };
  final messenger = ScaffoldMessenger.of(context);
  final count = await ref.read(shoppingRepositoryProvider).addRecipe(recipe, ingredients);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        count == 0
            ? '„${recipe.title}“ hat keine Zutaten.'
            : '$count Zutaten von „${recipe.title}“ stehen auf der Einkaufsliste.',
      ),
    ),
  );
}

/// Reiter „Rezepte“: Suche, Tag-Filter, Liste mit Zeit und kcal.
class RecipesTab extends ConsumerStatefulWidget {
  const RecipesTab({super.key});

  @override
  ConsumerState<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<RecipesTab> {
  var _query = '';
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesProvider);
    final ingredients = {
      for (final ingredient in ref.watch(ingredientsProvider).value ?? const <Ingredient>[]) ingredient.id: ingredient,
    };
    final tags = ref.watch(tagsProvider(TagScope.recipes)).value ?? const <TagItem>[];
    final tagMap = {for (final tag in tags) tag.id: tag};

    return recipes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (all) {
        final query = _query.trim().toLowerCase();
        final visible = [
          for (final recipe in all)
            if ((_tag == null || recipe.tagIds.contains(_tag)) &&
                (query.isEmpty || recipe.title.toLowerCase().contains(query)))
              recipe,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rezept suchen'),
              onChanged: (value) => setState(() => _query = value),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(label: const Text('Alle'), selected: _tag == null, onSelected: (_) => setState(() => _tag = null)),
                  for (final tag in tags)
                    ChoiceChip(
                      avatar: CircleAvatar(radius: 6, backgroundColor: tagColor(tag.colorIndex)),
                      label: Text(tag.name),
                      selected: _tag == tag.id,
                      onSelected: (selected) => setState(() => _tag = selected ? tag.id : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (visible.isEmpty)
              EmptyState(
                icon: Icons.menu_book_outlined,
                message: all.isEmpty ? 'Noch keine Rezepte. Leg dein erstes an.' : 'Kein Rezept passt zur Suche.',
              ),
            for (final recipe in visible)
              Card(
                child: ListTile(
                  title: Text(recipe.title, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    [
                      if (recipe.minutes != null) '${recipe.minutes} Min',
                      '${perServing(recipeNutrition(recipe, ingredients), recipe.servings).kcal.round()} kcal pro Portion',
                      for (final id in recipe.tagIds)
                        if (tagMap[id] != null) tagMap[id]!.name,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Auf die Einkaufsliste',
                    icon: const Icon(Icons.add_shopping_cart),
                    onPressed: () => addRecipeToShoppingList(context, ref, recipe),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipeId: recipe.id)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
