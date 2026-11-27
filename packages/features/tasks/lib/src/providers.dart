import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_item.dart';
import 'task_repository.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => throw UnimplementedError(
    'taskRepositoryProvider muss in main() überschrieben werden.',
  ),
);

/// Alle Aufgaben, live aus der Datenbank.
final tasksProvider = StreamProvider<List<TaskItem>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAll(),
);

/// Unterpunkte eines Projekts, live aus der Datenbank.
final projectTasksProvider = StreamProvider.family<List<TaskItem>, String>(
  (ref, projectId) => ref.watch(taskRepositoryProvider).watchByProject(projectId),
);
