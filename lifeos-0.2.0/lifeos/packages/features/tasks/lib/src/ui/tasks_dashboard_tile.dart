import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';

/// Dashboard-Kachel: offene Aufgaben zum direkten Abhaken.
class TasksDashboardTile extends ConsumerWidget {
  const TasksDashboardTile({super.key, required this.onOpenAll, this.maxItems = 5});

  final VoidCallback onOpenAll;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    return SectionCard(
      title: 'Aufgaben',
      icon: Icons.check_box_outlined,
      action: TextButton(onPressed: onOpenAll, child: const Text('Alle')),
      child: tasks.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text('Fehler: $error'),
        data: (items) {
          final open = items.where((task) => !task.done).toList();
          if (open.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Alles erledigt.'),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                open.length == 1 ? '1 offene Aufgabe' : '${open.length} offene Aufgaben',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final task in open.take(maxItems))
                CheckboxListTile(
                  value: false,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (_) => ref.read(taskRepositoryProvider).setDone(task.id, true),
                ),
            ],
          );
        },
      ),
    );
  }
}
