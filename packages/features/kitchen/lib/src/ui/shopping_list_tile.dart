import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';

/// Dashboard-Kachel: offene Einträge der Einkaufsliste.
class ShoppingListTile extends ConsumerWidget {
  const ShoppingListTile({super.key, required this.onOpen, this.maxItems = 5});

  final VoidCallback onOpen;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = [for (final item in ref.watch(shoppingItemsProvider).value ?? const <ShoppingItem>[]) if (!item.checked) item];
    return SectionCard(
      title: 'Einkaufsliste',
      icon: Icons.shopping_cart_outlined,
      action: TextButton(onPressed: onOpen, child: const Text('Öffnen')),
      child: open.isEmpty
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nichts zu kaufen.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(open.length == 1 ? '1 Artikel offen' : '${open.length} Artikel offen',
                    style: Theme.of(context).textTheme.bodySmall),
                for (final item in open.take(maxItems))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      item.amount == null ? item.name : '${item.name} · ${formatQuantity(item.amount, item.unit)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (open.length > maxItems)
                  Text('und ${open.length - maxItems} weitere', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }
}
