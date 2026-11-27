import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../model.dart';
import '../providers.dart';

/// Dashboard-Kachel: aktive Projekte mit Fortschritt.
class ProjectsTile extends ConsumerWidget {
  const ProjectsTile({
    super.key,
    required this.onOpenAll,
    required this.onOpenProject,
    this.clock,
    this.maxItems = 3,
  });

  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenProject;
  final DateTime Function()? clock;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly((clock ?? DateTime.now)());
    final active = [for (final p in ref.watch(projectsProvider).value ?? const <Project>[]) if (p.isActive) p];
    return SectionCard(
      title: 'Projekte',
      icon: Icons.work_outline,
      action: TextButton(onPressed: onOpenAll, child: const Text('Alle')),
      child: active.isEmpty
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Keine aktiven Projekte.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final project in active.take(maxItems))
                  _ProjectRow(project: project, today: today, onTap: () => onOpenProject(project.id)),
                if (active.length > maxItems)
                  Text('und ${active.length - maxItems} weitere', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({required this.project, required this.today, required this.onTap});

  final Project project;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtasks = ref.watch(projectTasksProvider(project.id)).value ?? const <TaskItem>[];
    final percent = (progressOf(subtasks) * 100).round();
    final deadline = project.deadline;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(project.name, style: theme.textTheme.titleSmall)),
                Text('$percent %'),
              ],
            ),
            const SizedBox(height: 4),
            BudgetBar(
              value: subtasks.where((task) => task.done).length,
              limit: subtasks.isEmpty ? 1 : subtasks.length,
              color: tagColor(project.colorIndex),
            ),
            if (deadline != null) ...[
              const SizedBox(height: 2),
              Text(deadlineText(deadline, today)!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
