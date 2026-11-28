import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learning_repository.dart';
import 'model.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => throw UnimplementedError('learningRepositoryProvider muss in main() überschrieben werden.'),
);

final learningAreasProvider = StreamProvider<List<LearningArea>>(
  (ref) => ref.watch(learningRepositoryProvider).watchAreas(),
);

final glossaryProvider = StreamProvider.family<List<GlossaryEntry>, String>(
  (ref, areaId) => ref.watch(learningRepositoryProvider).watchGlossary(areaId),
);

final flashcardsProvider = StreamProvider.family<List<Flashcard>, String>(
  (ref, areaId) => ref.watch(learningRepositoryProvider).watchCards(areaId),
);

final learningResourcesProvider = StreamProvider.family<List<LearningResource>, String>(
  (ref, areaId) => ref.watch(learningRepositoryProvider).watchResources(areaId),
);

/// Alle Lerneinheiten, neueste zuerst.
final studySessionsProvider = StreamProvider<List<StudySession>>(
  (ref) => ref.watch(learningRepositoryProvider).watchSessions(),
);

/// Ein Projekt, mit dem ein Lernbereich verknüpft werden kann.
class LearningProjectChoice {
  const LearningProjectChoice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Projekte für die Auswahl beim Lernbereich. Die App liefert sie; ohne
/// Überschreiben gibt es keine Auswahl.
final learningProjectChoicesProvider = StreamProvider<List<LearningProjectChoice>>(
  (ref) => Stream.value(const <LearningProjectChoice>[]),
);
