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
