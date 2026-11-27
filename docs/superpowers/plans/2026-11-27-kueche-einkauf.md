# Welle C: Küche und Einkaufsliste – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LifeOS 0.5.0 mit Zutaten-Datenbank, Rezepten mit berechneten Nährwerten und Einkaufsliste, deren „Gekauft“ eine Ausgabe in den Finanzen bucht.

**Architecture:** Schema 5 (`ingredients`, `recipes`, `shopping_items`), Tag-Bereich `recipes`. Neues Paket `lifeos_kitchen` nutzt Tags und Finanzen direkt; „Gekauft“ läuft in einer Transaktion über dieselbe Datenbank.

**Tech Stack:** wie bisher, keine neuen Pakete.

**Spec:** `docs/superpowers/specs/2026-11-27-kueche-einkauf-design.md`

## Global Constraints

- Zutat-ID: `Ids.deterministic('ingredient', Ids.normalizeName(name))`.
- Nährwerte je 100 g/ml bzw. je Stück, als `double`; Rezeptwerte immer berechnet.
- Mengen: Komma oder Punkt als Dezimalzeichen, Anzeige mit Komma, höchstens 2 Nachkommastellen.
- „Gekauft“: Ausgabe (`EntryKind.expense`) und Entfernen der abgehakten Einträge in einer Transaktion.

## Review Focus

- Rezept enthält eine inzwischen gelöschte Zutat → Rest wird berechnet, Zutat als „gelöscht“ angezeigt → Test in Task 2.
- „Gekauft“ ohne abgehakte Einträge → nichts gebucht → Test in Task 2.
- Gleiche Zutat in zwei Einheiten auf der Liste (g und Stück) → nicht zusammengezählt → Test in Task 2.
- Upgrade von Schema 2, 3 und 4 auf 5 → Test in Task 1.
- Sehr langer Einkauf → Buchungstitel bleibt kurz → Test in Task 2.

---

### Task 1: Schema 5, Sync, Tag-Bereich
Files: `packages/persistence/lib/src/{tables,database}.dart`, `test/migration_test.dart`; `packages/sync/lib/src/entity_schema.dart`; `packages/features/tags/lib/src/tag_item.dart`.
Produces: Tabellen `Ingredients` (`IngredientRow`), `Recipes` (`RecipeRow`), `ShoppingItems` (`ShoppingItemRow`); `TagScope.recipes`.

### Task 2: Küchenlogik
Files: Paket `packages/features/kitchen`: `model.dart`, `nutrition.dart`, `ingredient_repository.dart`, `recipe_repository.dart`, `shopping_repository.dart`, `providers.dart`; Tests `nutrition_test.dart`, `kitchen_repository_test.dart`.
Produces: `IngredientUnit`, `Ingredient`, `RecipeIngredient`, `Recipe`, `RecipeDraft`, `ShoppingItem`, `Nutrition`, `nutritionOf`, `recipeNutrition`, `parseAmount`, `formatAmount`, `formatQuantity`, `IngredientRepository` (`idFor`, `watchAll`, `create`, `update`, `delete`), `RecipeRepository` (`watchAll`, `create`, `update`, `delete`), `ShoppingRepository` (`watchAll`, `addManual`, `addRecipe`, `setChecked`, `remove`, `checkout`), Provider `ingredientsProvider`, `recipesProvider`, `shoppingItemsProvider`.

### Task 3: Küchen-Oberfläche
Files: `lib/src/ui/{kitchen_page,recipes_tab,recipe_detail_page,recipe_editor_page,ingredient_dialog,ingredients_tab,shopping_tab,checkout_dialog,shopping_list_tile}.dart`; Test `kitchen_page_test.dart`.
Produces: `KitchenPage`, `ShoppingListTile({onOpen})`.

### Task 4: App, Build, Downloads
Files: App (`pubspec.yaml` 0.5.0+5, `main.dart`, `bootstrap.dart`, `router.dart`, `dashboard_page.dart`), Wurzel-`pubspec.yaml`, `tool/test.ps1`, `README.md`, `docs/adr/0007-kueche.md`.
Check: CI auf `welle-c` grün, `main` vorspulen, Artifacts beider Jobs im `main`-Lauf vorhanden.
