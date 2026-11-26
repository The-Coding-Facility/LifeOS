import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';
import '../task_item.dart';

/// Liste aller Aufgaben mit Eingabezeile.
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  /// Sofort ausgeblendete Aufgaben, bis die Datenbank die Löschung meldet.
  /// Verhindert, dass ein weggewischter Eintrag kurz wieder auftaucht.
  final _hidden = <String>{};

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (title.isEmpty) return;
    await ref.read(taskRepositoryProvider).create(title);
    _input.clear();
    _inputFocus.requestFocus();
  }

  Future<void> _delete(TaskItem task) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(task.id));
    await ref.read(taskRepositoryProvider).delete(task.id);
    messenger.showSnackBar(SnackBar(content: Text('„${task.title}“ gelöscht')));
  }

  Future<void> _rename(TaskItem task) async {
    final controller = TextEditingController(text: task.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgabe umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    await ref.read(taskRepositoryProvider).rename(task.id, result);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Neue Aufgabe',
                      prefixIcon: Icon(Icons.add_task),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Hinzufügen',
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Fehler beim Laden: $error')),
              data: (all) {
                final items = all.where((task) => !_hidden.contains(task.id)).toList();
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.check_circle_outline,
                    message: 'Keine Aufgaben. Schreib oben die erste hinein.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final task = items[index];
                    return _TaskTile(
                      task: task,
                      onToggle: (done) =>
                          ref.read(taskRepositoryProvider).setDone(task.id, done),
                      onRename: () => _rename(task),
                      onDelete: () => _delete(task),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  final TaskItem task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          onChanged: (value) => onToggle(value ?? false),
        ),
        title: Text(
          task.title,
          style: task.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: task.details == null ? null : Text(task.details!),
        onTap: onRename,
        trailing: IconButton(
          tooltip: 'Löschen',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
