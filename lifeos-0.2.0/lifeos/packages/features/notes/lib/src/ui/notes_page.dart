import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';
import 'format.dart';

/// Liste aller Notizen.
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key, required this.onOpenNote});

  /// Öffnet den Editor für die Notiz mit dieser ID.
  final ValueChanged<String> onOpenNote;

  Future<void> _create(WidgetRef ref) async {
    final id = await ref.read(noteRepositoryProvider).create();
    onOpenNote(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notizen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(ref),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Neue Notiz'),
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler beim Laden: $error')),
        data: (items) {
          final visible = items.where((note) => !note.isEmpty).toList();
          if (visible.isEmpty) {
            return const EmptyState(
              icon: Icons.sticky_note_2_outlined,
              message: 'Noch keine Notizen.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: visible.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = visible[index];
              return ListTile(
                title: Text(note.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: note.preview.isEmpty
                    ? null
                    : Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Text(
                  formatShortDate(note.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => onOpenNote(note.id),
              );
            },
          );
        },
      ),
    );
  }
}
