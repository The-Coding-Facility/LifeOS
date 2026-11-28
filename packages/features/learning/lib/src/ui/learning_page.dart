import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../model.dart';
import '../providers.dart';
import 'area_page.dart';

/// Liste der Lernbereiche.
class LearningPage extends ConsumerWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final areas = ref.watch(learningAreasProvider);
    final sessions = ref.watch(studySessionsProvider).value ?? const <StudySession>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Lernen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editLearningArea(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Lernbereich'),
      ),
      body: areas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              message: 'Noch keine Lernbereiche. Leg einen an, z. B. „Spanisch“ oder „Führerschein“.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              for (final area in all)
                Builder(builder: (context) {
                  final own = [for (final s in sessions) if (s.areaId == area.id) s];
                  final last = own.isEmpty ? null : own.first;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: tagColor(area.colorIndex), radius: 10),
                      title: Text(area.name, style: theme.textTheme.titleMedium),
                      subtitle: Text(
                        last == null
                            ? 'Noch nicht gelernt'
                            : '${own.length} Einheiten · zuletzt ${formatDate(last.startedAt)} · '
                                '${(last.rate * 100).round()} % richtig',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => LearningAreaPage(areaId: area.id)),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

/// Dialog zum Anlegen oder Bearbeiten eines Lernbereichs.
Future<void> editLearningArea(BuildContext context, WidgetRef ref, {LearningArea? area}) async {
  final result = await showDialog<({String name, String description, int color, String? projectId})>(
    context: context,
    builder: (context) => _AreaDialog(area: area),
  );
  if (result == null) return;
  final repository = ref.read(learningRepositoryProvider);
  if (area == null) {
    await repository.createArea(
      name: result.name,
      description: result.description,
      colorIndex: result.color,
      projectId: result.projectId,
    );
  } else {
    await repository.updateArea(
      area.id,
      name: result.name,
      description: result.description,
      colorIndex: result.color,
      projectId: result.projectId,
    );
  }
}

class _AreaDialog extends ConsumerStatefulWidget {
  const _AreaDialog({this.area});

  final LearningArea? area;

  @override
  ConsumerState<_AreaDialog> createState() => _AreaDialogState();
}

class _AreaDialogState extends ConsumerState<_AreaDialog> {
  late final _name = TextEditingController(text: widget.area?.name ?? '');
  late final _description = TextEditingController(text: widget.area?.description ?? '');
  late var _color = widget.area?.colorIndex ?? 0;
  late String? _projectId = widget.area?.projectId;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(learningProjectChoicesProvider).value ?? const <LearningProjectChoice>[];
    return AlertDialog(
      title: Text(widget.area == null ? 'Neuer Lernbereich' : 'Lernbereich bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.area == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
            ),
            if (projects.isNotEmpty || _projectId != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Projekt'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Kein Projekt')),
                  for (final project in projects)
                    DropdownMenuItem<String?>(value: project.id, child: Text(project.name)),
                  if (_projectId != null && !projects.any((p) => p.id == _projectId))
                    DropdownMenuItem<String?>(value: _projectId, child: const Text('Abgeschlossenes Projekt')),
                ],
                onChanged: (value) => setState(() => _projectId = value),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < tagPaletteSize; index++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = index),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: tagColor(index),
                      child: index == _color ? Icon(Icons.check, size: 16, color: onTagColor(tagColor(index))) : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              (name: _name.text.trim(), description: _description.text.trim(), color: _color, projectId: _projectId),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
