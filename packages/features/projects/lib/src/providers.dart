import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model.dart';
import 'project_repository.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => throw UnimplementedError('projectRepositoryProvider muss in main() überschrieben werden.'),
);

/// Alle Projekte.
final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);
