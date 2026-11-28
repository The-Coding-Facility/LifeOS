import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_learning/lifeos_learning.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../model.dart';
import '../providers.dart';
import 'project_editor.dart';

/// Dashboard eines Projekts: Fortschritt, Unterpunkte, Notizen, Termine.
class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.onOpenNote,
    required this.onClose,
    this.clock,
  });

  final String projectId;
  final ValueChanged<String> onOpenNote;
  final VoidCallback onClose;
  final DateTime Function()? clock;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  final _newTask = TextEditingController();

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    await ref.read(taskRepositoryProvider).create(title, projectId: widget.projectId);
    _newTask.clear();
  }

  Future<void> _delete(Project project, List<TaskItem> subtasks) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Projekt „${project.name}“ löschen?'),
        content: const Text(
          'Das Projekt und seine Unterpunkte werden auf allen Geräten gelöscht. '
          'Notizen und Termine bleiben erhalten.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    final tasks = ref.read(taskRepositoryProvider);
    for (final task in subtasks) {
      await tasks.delete(task.id);
    }
    await ref.read(projectRepositoryProvider).delete(project.id);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dateOnly((widget.clock ?? DateTime.now)());
    final projects = ref.watch(projectsProvider);
    final project = projects.value?.where((p) => p.id == widget.projectId).firstOrNull;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: widget.onClose)),
        body: projects.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.work_off_outlined, message: 'Dieses Projekt gibt es nicht mehr.'),
      );
    }

    final subtasks = ref.watch(projectTasksProvider(project.id)).value ?? const <TaskItem>[];
    final notes = ref.watch(projectNotesProvider(project.id)).value ?? const <NoteItem>[];
    final events = ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
    final upcoming = expandAll(
      [for (final event in events) if (event.projectId == project.id) event],
      today,
      DateTime(today.year, today.month, today.day + 90),
    );
    final areas = [
      for (final area in ref.watch(learningAreasProvider).value ?? const <LearningArea>[])
        if (area.projectId == project.id) area,
    ];
    final sessions = ref.watch(studySessionsProvider).value ?? const <StudySession>[];
    final done = subtasks.where((task) => task.done).length;
    final percent = (progressOf(subtasks) * 100).round();
    final deadline = project.deadline;

    Widget section(String title, IconData icon, {Widget? action}) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              if (action != null) action,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onClose),
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final draft = await showProjectEditor(context, project: project);
              if (draft != null) await ref.read(projectRepositoryProvider).update(project.id, draft);
            },
          ),
          IconButton(
            tooltip: project.isActive ? 'Abschließen' : 'Wieder öffnen',
            icon: Icon(project.isActive ? Icons.task_alt : Icons.replay),
            onPressed: () => ref.read(projectRepositoryProvider).setStatus(
                  project.id,
                  project.isActive ? ProjectStatus.done : ProjectStatus.active,
                ),
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(project, subtasks),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!project.isActive)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Chip(avatar: Icon(Icons.task_alt, size: 18), label: Text('Abgeschlossen')),
            ),
          if (project.description.isNotEmpty) Text(project.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BudgetBar(
                  value: done,
                  limit: subtasks.isEmpty ? 1 : subtasks.length,
                  color: tagColor(project.colorIndex),
                ),
              ),
              const SizedBox(width: 12),
              Text('$percent %', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              subtasks.isEmpty ? 'Noch keine Unterpunkte' : '$done von ${subtasks.length} Unterpunkten erledigt',
              if (deadline != null) describeDeadline(deadline, today),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),

          section('Unterpunkte', Icons.checklist),
          TextField(
            controller: _newTask,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Neuer Unterpunkt',
              suffixIcon: IconButton(tooltip: 'Hinzufügen', icon: const Icon(Icons.add), onPressed: _addTask),
            ),
            onSubmitted: (_) => _addTask(),
          ),
          for (final task in subtasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: task.done,
              title: Text(
                task.title,
                style: task.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
              ),
              secondary: IconButton(
                tooltip: 'Entfernen',
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(taskRepositoryProvider).delete(task.id),
              ),
              onChanged: (value) => ref.read(taskRepositoryProvider).setDone(task.id, value ?? false),
            ),

          section(
            'Notizen',
            Icons.sticky_note_2_outlined,
            action: TextButton.icon(
              onPressed: () async {
                final id = await ref.read(noteRepositoryProvider).create(projectId: project.id);
                widget.onOpenNote(id);
              },
              icon: const Icon(Icons.add),
              label: const Text('Neue Notiz'),
            ),
          ),
          if (notes.isEmpty) Text('Noch keine Notizen zu diesem Projekt.', style: theme.textTheme.bodySmall),
          for (final note in notes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(note.pinned ? Icons.push_pin : Icons.notes),
              title: Text(note.displayTitle),
              subtitle: note.preview.isEmpty ? null : Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => widget.onOpenNote(note.id),
            ),

          section(
            'Termine',
            Icons.event_outlined,
            action: TextButton.icon(
              onPressed: () => openEventEditor(
                context,
                initialStart: DateTime(today.year, today.month, today.day + 1, 9),
                initialProjectId: project.id,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Termin anlegen'),
            ),
          ),
          if (upcoming.isEmpty)
            Text('Keine Termine in den nächsten 90 Tagen.', style: theme.textTheme.bodySmall),
          for (final occurrence in upcoming.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(occurrence.event.title),
              subtitle: Text(
                '${formatDateShort(occurrence.start)} '
                '${occurrence.allDay ? 'ganztägig' : formatTime(occurrence.start)}',
              ),
              onTap: () => openEventEditor(context, occurrence: occurrence),
            ),

          if (areas.isNotEmpty) section('Lernbereiche', Icons.school_outlined),
          for (final area in areas)
            Builder(
              builder: (context) {
                final summary = areaSummary(sessions, area.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 8, backgroundColor: tagColor(area.colorIndex)),
                  title: Text(area.name),
                  subtitle: Text(
                    summary.count == 0
                        ? 'Noch nicht gelernt'
                        : '${summary.count} Einheiten'
                            '${summary.rate == null ? '' : ' · ${(summary.rate! * 100).round()} % richtig'}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => LearningAreaPage(areaId: area.id)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
