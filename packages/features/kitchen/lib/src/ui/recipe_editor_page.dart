import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';
import 'ingredient_dialog.dart';

/// Öffnet das Formular für ein neues oder bestehendes Rezept.
Future<void> openRecipeEditor(BuildContext context, {Recipe? recipe}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => RecipeEditorPage(recipe: recipe)),
  );
}

class _Row {
  _Row(this.ingredientId, double? amount)
      : controller = TextEditingController(text: amount == null ? '' : formatAmount(amount));

  final String ingredientId;
  final TextEditingController controller;
}

/// Vorschlag in der Zutatensuche: vorhandene Zutat oder „neu anlegen“.
class _Option {
  const _Option.existing(Ingredient this.ingredient) : newName = null;
  const _Option.create(String this.newName) : ingredient = null;

  final Ingredient? ingredient;
  final String? newName;
}

/// Formular für ein Rezept mit Zutatensuche und Nährwert-Vorschau.
class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, this.recipe});

  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  late final _title = TextEditingController(text: widget.recipe?.title ?? '');
  late final _minutes = TextEditingController(text: widget.recipe?.minutes?.toString() ?? '');
  late final _preparation = TextEditingController(text: widget.recipe?.preparation ?? '');
  late var _servings = widget.recipe?.servings ?? 2;
  late var _tagIds = [...?widget.recipe?.tagIds];
  late final List<_Row> _rows = [
    for (final item in widget.recipe?.ingredients ?? const <RecipeIngredient>[]) _Row(item.ingredientId, item.amount),
  ];
  TextEditingController? _search;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    _preparation.dispose();
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _addRow(String ingredientId) {
    setState(() {
      if (_rows.any((row) => row.ingredientId == ingredientId)) return;
      _rows.add(_Row(ingredientId, null));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _search?.clear());
  }

  Future<void> _select(_Option option) async {
    final existing = option.ingredient;
    if (existing != null) {
      _addRow(existing.id);
      return;
    }
    final id = await showIngredientDialog(context, ref, initialName: option.newName ?? '');
    if (id != null && mounted) _addRow(id);
  }

  List<RecipeIngredient>? _parsedIngredients() {
    final result = <RecipeIngredient>[];
    for (final row in _rows) {
      final amount = parseAmount(row.controller.text);
      if (amount == null || amount == 0) return null;
      result.add(RecipeIngredient(ingredientId: row.ingredientId, amount: amount));
    }
    return result;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Bitte gib einen Titel ein.');
      return;
    }
    final items = _parsedIngredients();
    if (items == null) {
      setState(() => _error = 'Bitte bei jeder Zutat eine Menge eingeben, z. B. 250 oder 1,5.');
      return;
    }
    final draft = RecipeDraft(
      title: _title.text,
      minutes: int.tryParse(_minutes.text.trim()),
      servings: _servings,
      tagIds: _tagIds,
      ingredients: items,
      preparation: _preparation.text,
    );
    final repository = ref.read(recipeRepositoryProvider);
    if (widget.recipe == null) {
      await repository.create(draft);
    } else {
      await repository.update(widget.recipe!.id, draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredients = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final byId = {for (final ingredient in ingredients) ingredient.id: ingredient};
    final preview = recipeNutrition(
      Recipe(
        id: '',
        title: '',
        ingredients: [
          for (final row in _rows)
            if (parseAmount(row.controller.text) case final amount?)
              RecipeIngredient(ingredientId: row.ingredientId, amount: amount),
        ],
      ),
      byId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Neues Rezept' : 'Rezept bearbeiten'),
        actions: [TextButton(onPressed: _save, child: const Text('Speichern'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.recipe == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Titel'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Zeit in Minuten', prefixIcon: Icon(Icons.timer_outlined)),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Portionen'),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
              ),
              Text('$_servings', style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _servings < 50 ? () => setState(() => _servings++) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Tags', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TagSelector(scope: TagScope.recipes, selectedIds: _tagIds, onChanged: (ids) => setState(() => _tagIds = ids)),
          const SizedBox(height: 16),
          Text('Zutaten', style: theme.textTheme.titleSmall),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(byId[row.ingredientId]?.name ?? 'Gelöschte Zutat', style: theme.textTheme.bodyLarge),
                  ),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: row.controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(hintText: 'Menge', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(' ${byId[row.ingredientId]?.unit.label ?? ''}'),
                  ),
                  IconButton(
                    tooltip: 'Entfernen',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _rows.remove(row);
                      row.controller.dispose();
                    }),
                  ),
                ],
              ),
            ),
          Autocomplete<_Option>(
            displayStringForOption: (option) => option.ingredient?.name ?? option.newName ?? '',
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              if (query.isEmpty) return const <_Option>[];
              final matches = [
                for (final ingredient in ingredients)
                  if (ingredient.name.toLowerCase().contains(query)) _Option.existing(ingredient),
              ];
              final exact = ingredients.any((ingredient) => ingredient.name.toLowerCase() == query);
              return [...matches.take(8), if (!exact) _Option.create(value.text.trim())];
            },
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final option in options)
                        ListTile(
                          leading: Icon(option.ingredient == null ? Icons.add : Icons.kitchen_outlined),
                          title: Text(
                            option.ingredient?.name ?? 'Neue Zutat „${option.newName}“ anlegen',
                          ),
                          subtitle: option.ingredient == null
                              ? null
                              : Text(
                                  '${option.ingredient!.unit.perLabel}: ${option.ingredient!.kcal.round()} kcal',
                                ),
                          onTap: () => onSelected(option),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            onSelected: _select,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              _search = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Zutat suchen oder neu anlegen',
                  prefixIcon: Icon(Icons.search),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Pro Portion: ${perServing(preview, _servings).describe()}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _preparation,
            minLines: 6,
            maxLines: 20,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Zubereitung', alignLabelWithHint: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
