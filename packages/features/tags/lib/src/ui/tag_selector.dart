import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';
import '../tag_item.dart';

/// Auswahl von Tags als Chips, mit „Neuer Tag“ zum Anlegen.
class TagSelector extends ConsumerWidget {
  const TagSelector({
    super.key,
    required this.scope,
    required this.selectedIds,
    required this.onChanged,
  });

  final TagScope scope;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider(scope)).value ?? const <TagItem>[];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          FilterChip(
            avatar: CircleAvatar(backgroundColor: tagColor(tag.colorIndex), radius: 6),
            label: Text(tag.name),
            selected: selectedIds.contains(tag.id),
            onSelected: (selected) {
              final next = [...selectedIds.where((id) => id != tag.id)];
              if (selected) next.add(tag.id);
              onChanged(next);
            },
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Neuer Tag'),
          onPressed: () async {
            final created = await showNewTagDialog(context, ref, scope);
            if (created != null && !selectedIds.contains(created)) {
              onChanged([...selectedIds, created]);
            }
          },
        ),
      ],
    );
  }
}

/// Fragt Name und Farbe ab, legt den Tag an und gibt seine ID zurück.
Future<String?> showNewTagDialog(BuildContext context, WidgetRef ref, TagScope scope) async {
  final result = await showDialog<({String name, int color})>(
    context: context,
    builder: (context) => const _NewTagDialog(),
  );
  if (result == null) return null;
  return ref.read(tagRepositoryProvider).create(scope, result.name, colorIndex: result.color);
}

class _NewTagDialog extends StatefulWidget {
  const _NewTagDialog();

  @override
  State<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<_NewTagDialog> {
  final _name = TextEditingController();
  var _color = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'z. B. Sport'),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < tagPaletteSize; index++)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = index),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: tagColor(index),
                    child: index == _color
                        ? Icon(Icons.check, size: 18, color: onTagColor(tagColor(index)))
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Anlegen')),
      ],
    );
  }
}
