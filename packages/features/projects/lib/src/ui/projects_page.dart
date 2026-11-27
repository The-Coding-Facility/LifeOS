import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../model.dart';
import '../providers.dart';
import 'project_editor.dart';

/// Liste der Projekte mit Fortschritt.
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key, required this.onOpenProject, this.clock});

  final ValueChanged<String> onOpenProject;
  final DateTime Function()? clock;

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  var _status = ProjectStatus.active;

  Future<void> _create() async {
    final draft = await showProjectEditor(context);
    if (draft == null) return;
    final id = await ref.read(projectRepositoryProvider).create(draft);
    widget.onOpenProject(id);
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly((widget.clock ?? DateTime.now)());
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Projekte')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Neues Projekt'),
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
        data: (all) {
          final visible = [for (final project in all) if (project.status == _status) project];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<ProjectStatus>(
                  showSelectedIcon: false,
                  segments: [
                    for (final status in ProjectStatus.values)
                      ButtonSegment(value: status, label: Text(status.label)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (selection) => setState(() => _status = selection.first),
                ),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.work_outline,
                  message: _status == ProjectStatus.active
                      ? 'Keine aktiven Projekte. Leg eins an.'
                      : 'Noch keine abgeschlossenen Projekte.',
                ),
              for (final project in visible)
                ProjectCard(project: project, today: today, onTap: () => widget.onOpenProject(project.id)),
            ],
          );
        },
      ),
    );
  }
}

/// Karte mit Name, Fortschritt und Deadline.
class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project, required this.today, required this.onTap});

  final Project project;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtasks = ref.watch(projectTasksProvider(project.id)).value ?? const <TaskItem>[];
    final done = subtasks.where((task) => task.done).length;
    final percent = (progressOf(subtasks) * 100).round();
    final deadline = project.deadline;
    final overdue = deadline != null && project.isActive && deadline.isBefore(today);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 6, backgroundColor: tagColor(project.colorIndex)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(project.name, style: theme.textTheme.titleMedium)),
                  Text('$percent %', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              BudgetBar(value: done, limit: subtasks.isEmpty ? 1 : subtasks.length, color: tagColor(project.colorIndex)),
              const SizedBox(height: 6),
              Text(
                [
                  subtasks.isEmpty ? 'Noch keine Unterpunkte' : '$done von ${subtasks.length} erledigt',
                  if (deadline != null) describeDeadline(deadline, today),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: overdue ? theme.colorScheme.error : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
