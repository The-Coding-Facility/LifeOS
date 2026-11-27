import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';

/// Dashboard-Kachel mit angehefteten Notizen. Ohne angeheftete Notiz
/// erscheint sie nicht.
class PinnedNotesTile extends ConsumerWidget {
  const PinnedNotesTile({super.key, required this.onOpenNote});

  final ValueChanged<String> onOpenNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(pinnedNotesProvider).value ?? const [];
    if (notes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Angeheftet',
      icon: Icons.push_pin_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final note in notes)
            InkWell(
              onTap: () => onOpenNote(note.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.displayTitle, style: theme.textTheme.titleSmall),
                    if (note.preview.isNotEmpty)
                      Text(note.preview, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
