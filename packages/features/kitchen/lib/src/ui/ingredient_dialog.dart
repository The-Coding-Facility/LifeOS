import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';

/// Legt eine Zutat an oder bearbeitet sie. Gibt die ID zurück.
Future<String?> showIngredientDialog(
  BuildContext context,
  WidgetRef ref, {
  Ingredient? ingredient,
  String initialName = '',
}) async {
  final result = await showDialog<_IngredientResult>(
    context: context,
    builder: (context) => _IngredientDialog(ingredient: ingredient, initialName: initialName),
  );
  if (result == null) return null;
  final repository = ref.read(ingredientRepositoryProvider);
  if (result.delete && ingredient != null) {
    await repository.delete(ingredient.id);
    return null;
  }
  if (ingredient == null) {
    return repository.create(
      name: result.name,
      unit: result.unit,
      kcal: result.kcal,
      protein: result.protein,
      fat: result.fat,
    );
  }
  await repository.update(
    ingredient.id,
    name: result.name,
    unit: result.unit,
    kcal: result.kcal,
    protein: result.protein,
    fat: result.fat,
  );
  return ingredient.id;
}

class _IngredientResult {
  const _IngredientResult({
    required this.name,
    required this.unit,
    required this.kcal,
    required this.protein,
    required this.fat,
  }) : delete = false;

  const _IngredientResult.delete()
      : name = '',
        unit = IngredientUnit.gram,
        kcal = 0,
        protein = 0,
        fat = 0,
        delete = true;

  final String name;
  final IngredientUnit unit;
  final double kcal;
  final double protein;
  final double fat;
  final bool delete;
}

class _IngredientDialog extends StatefulWidget {
  const _IngredientDialog({this.ingredient, this.initialName = ''});

  final Ingredient? ingredient;
  final String initialName;

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  late final _name = TextEditingController(text: widget.ingredient?.name ?? widget.initialName);
  late final _kcal = TextEditingController(text: _initial(widget.ingredient?.kcal));
  late final _protein = TextEditingController(text: _initial(widget.ingredient?.protein));
  late final _fat = TextEditingController(text: _initial(widget.ingredient?.fat));
  late var _unit = widget.ingredient?.unit ?? IngredientUnit.gram;
  String? _error;

  static String _initial(double? value) => value == null ? '' : formatAmount(value);

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _save() {
    double? read(TextEditingController controller) =>
        controller.text.trim().isEmpty ? 0 : parseAmount(controller.text);
    final kcal = read(_kcal);
    final protein = read(_protein);
    final fat = read(_fat);
    if (_name.text.trim().isEmpty || kcal == null || protein == null || fat == null) {
      setState(() => _error = 'Bitte Name und gültige Zahlen eingeben, z. B. 3,5');
      return;
    }
    Navigator.of(context).pop(
      _IngredientResult(name: _name.text.trim(), unit: _unit, kcal: kcal, protein: protein, fat: fat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget numberField(TextEditingController controller, String label) => Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label),
          ),
        );

    return AlertDialog(
      title: Text(widget.ingredient == null ? 'Neue Zutat' : 'Zutat bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: _name.text.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'z. B. Vollmilch'),
            ),
            const SizedBox(height: 12),
            Text('Mengeneinheit', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<IngredientUnit>(
              showSelectedIcon: false,
              segments: [
                for (final unit in IngredientUnit.values) ButtonSegment(value: unit, label: Text(unit.label)),
              ],
              selected: {_unit},
              onSelectionChanged: (selection) => setState(() => _unit = selection.first),
            ),
            const SizedBox(height: 12),
            Text('Nährwerte ${_unit.perLabel}', style: theme.textTheme.labelLarge),
            Row(
              children: [
                numberField(_kcal, 'kcal'),
                const SizedBox(width: 8),
                numberField(_protein, 'Protein (g)'),
                const SizedBox(width: 8),
                numberField(_fat, 'Fett (g)'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.ingredient != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const _IngredientResult.delete()),
            child: const Text('Löschen'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
