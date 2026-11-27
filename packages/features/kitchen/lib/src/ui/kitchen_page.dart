import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ingredient_dialog.dart';
import 'ingredients_tab.dart';
import 'recipe_editor_page.dart';
import 'recipes_tab.dart';
import 'shopping_tab.dart';

/// Küche mit den Reitern Rezepte, Einkaufsliste und Zutaten.
class KitchenPage extends ConsumerStatefulWidget {
  const KitchenPage({super.key, this.initialTab = 0});

  /// 0 = Rezepte, 1 = Einkaufsliste, 2 = Zutaten.
  final int initialTab;

  @override
  ConsumerState<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends ConsumerState<KitchenPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = switch (_tabs.index) {
      0 => FloatingActionButton.extended(
          onPressed: () => openRecipeEditor(context),
          icon: const Icon(Icons.add),
          label: const Text('Neues Rezept'),
        ),
      2 => FloatingActionButton.extended(
          onPressed: () => showIngredientDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Neue Zutat'),
        ),
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Küche'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Rezepte'), Tab(text: 'Einkaufsliste'), Tab(text: 'Zutaten')],
        ),
      ),
      floatingActionButton: fab,
      body: TabBarView(
        controller: _tabs,
        children: const [RecipesTab(), ShoppingTab(), IngredientsTab()],
      ),
    );
  }
}
