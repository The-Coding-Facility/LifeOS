import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model.dart';
import '../nutrition.dart';
import '../providers.dart';

/// Reiter „Einkaufsliste“: abhaken, von Hand ergänzen, „Gekauft“.
class ShoppingTab extends ConsumerStatefulWidget {
  const ShoppingTab({super.key});

  @override
  ConsumerState<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends ConsumerState<ShoppingTab> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    await ref.read(shoppingRepositoryProvider).addManual(name);
    _input.clear();
  }

  Future<void> _checkout(int count) async {
    final result = await showDialog<({int cents, List<String> tags})>(
      context: context,
      builder: (context) => _CheckoutDialog(count: count),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final entryId = await ref.read(shoppingRepositoryProvider).checkout(totalCents: result.cents, tagIds: result.tags);
    messenger.showSnackBar(
      SnackBar(
        content: Text(entryId == null ? 'Nichts abgehakt.' : 'Ausgabe von ${formatCents(result.cents)} gebucht.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(shoppingItemsProvider).value ?? const <ShoppingItem>[];
    final checked = items.where((item) => item.checked).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _input,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Artikel hinzufügen, z. B. Klopapier',
              suffixIcon: IconButton(tooltip: 'Hinzufügen', icon: const Icon(Icons.add), onPressed: _add),
            ),
            onSubmitted: (_) => _add(),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  message: 'Die Einkaufsliste ist leer. Füge Artikel hinzu oder nutze den Einkaufswagen bei einem Rezept.',
                )
              : ListView(
                  children: [
                    for (final item in items)
                      Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: theme.colorScheme.errorContainer,
                          child: const Icon(Icons.delete_outline),
                        ),
                        onDismissed: (_) => ref.read(shoppingRepositoryProvider).remove(item.id),
                        child: CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          value: item.checked,
                          title: Text(
                            item.name,
                            style: item.checked ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                          ),
                          subtitle: item.amount == null ? null : Text(formatQuantity(item.amount, item.unit)),
                          onChanged: (value) =>
                              ref.read(shoppingRepositoryProvider).setChecked(item.id, value ?? false),
                        ),
                      ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: checked == 0 ? null : () => _checkout(checked),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(checked == 0 ? 'Gekauft' : 'Gekauft ($checked)'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({required this.count});

  final int count;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _sum = TextEditingController();
  var _tags = <String>[];
  String? _error;

  @override
  void dispose() {
    _sum.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = parseCents(_sum.text)?.abs();
    if (cents == null || cents == 0) {
      setState(() => _error = 'Bitte die Summe eingeben, z. B. 12,50');
      return;
    }
    Navigator.of(context).pop((cents: cents, tags: _tags));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.count == 1 ? '1 Artikel gekauft' : '${widget.count} Artikel gekauft'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _sum,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Summe in €', errorText: _error),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text('Finanz-Tag', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TagSelector(scope: TagScope.finance, selectedIds: _tags, onChanged: (ids) => setState(() => _tags = ids)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Ausgabe buchen')),
      ],
    );
  }
}
