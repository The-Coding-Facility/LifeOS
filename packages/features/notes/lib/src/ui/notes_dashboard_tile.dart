import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';
import 'format.dart';

/// Dashboard-Kachel: zuletzt bearbeitete Notizen.
class NotesDashboardTile extends ConsumerWidget {
  const NotesDashboardTile({
    super.key,
    required this.onOpenAll,
    required this.onOpenNote,
    this.maxItems = 3,
  });

  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenNote;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    return SectionCard(
      title: 'Notizen',
      icon: Icons.sticky_note_2_outlined,
      action: TextButton(onPressed: onOpenAll, child: const Text('Alle')),
      child: notes.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text('Fehler: $error'),
        data: (items) {
          final recent = items.where((note) => !note.isEmpty).take(maxItems).toList();
          if (recent.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Noch keine Notizen.'),
            );
          }
          return Column(
            children: [
              for (final note in recent)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatShortDate(note.updatedAt)),
                  onTap: () => onOpenNote(note.id),
                ),
            ],
          );
        },
      ),
    );
  }
}
