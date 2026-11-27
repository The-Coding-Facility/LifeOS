import 'package:flutter/material.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../model.dart';

/// Dialog für Name, Beschreibung, Deadline und Farbe eines Projekts.
Future<ProjectDraft?> showProjectEditor(BuildContext context, {Project? project}) {
  return showDialog<ProjectDraft>(
    context: context,
    builder: (context) => _ProjectDialog(project: project),
  );
}

class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({this.project});

  final Project? project;

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late final _name = TextEditingController(text: widget.project?.name ?? '');
  late final _description = TextEditingController(text: widget.project?.description ?? '');
  late DateTime? _deadline = widget.project?.deadline;
  late var _color = widget.project?.colorIndex ?? 0;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      ProjectDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        deadline: _deadline,
        colorIndex: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project == null ? 'Neues Projekt' : 'Projekt bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.project == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Deadline'),
              subtitle: Text(_deadline == null ? 'Keine' : formatDate(_deadline!)),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      tooltip: 'Keine Deadline',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
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
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
