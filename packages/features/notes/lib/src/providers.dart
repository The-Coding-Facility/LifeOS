import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_item.dart';
import 'note_repository.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => throw UnimplementedError(
    'noteRepositoryProvider muss in main() überschrieben werden.',
  ),
);

/// Alle Notizen, live aus der Datenbank.
final notesProvider = StreamProvider<List<NoteItem>>(
  (ref) => ref.watch(noteRepositoryProvider).watchAll(),
);

/// An die Übersicht angeheftete Notizen.
final pinnedNotesProvider = StreamProvider<List<NoteItem>>(
  (ref) => ref.watch(noteRepositoryProvider).watchPinned(),
);

/// Notizen eines Projekts.
final projectNotesProvider = StreamProvider.family<List<NoteItem>, String>(
  (ref, projectId) => ref.watch(noteRepositoryProvider).watchByProject(projectId),
);

/// Notizen eines Lernbereichs.
final learningAreaNotesProvider = StreamProvider.family<List<NoteItem>, String>(
  (ref, areaId) => ref.watch(noteRepositoryProvider).watchByLearningArea(areaId),
);
