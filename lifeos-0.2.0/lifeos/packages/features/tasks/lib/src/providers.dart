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
