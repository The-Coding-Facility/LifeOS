import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../finance_math.dart';
import '../model.dart';
import '../providers.dart';
import 'common.dart';

/// Reiter „Sparziele“.
class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  Future<void> _editGoal(BuildContext context, WidgetRef ref, {SavingGoal? goal}) async {
    final result = await showDialog<({String name, int target, DateTime? date})>(
      context: context,
      builder: (context) => _GoalDialog(goal: goal),
    );
    if (result == null) return;
    final repository = ref.read(financeRepositoryProvider);
    if (goal == null) {
      await repository.addGoal(result.name, result.target, targetDate: result.date);
    } else {
      await repository.updateGoal(
        goal.id,
        name: result.name,
        targetCents: result.target,
        targetDate: result.date,
        clearDate: result.date == null,
      );
    }
  }

  Future<void> _deleteGoal(BuildContext context, WidgetRef ref, SavingGoal goal, int saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sparziel „${goal.name}“ löschen?'),
        content: Text(
          saved > 0
              ? '${formatCents(saved)} kommen zurück auf deinen Kontostand.'
              : 'Das Sparziel wird auf allen Geräten gelöscht.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(financeRepositoryProvider).deleteGoal(goal.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goals = ref.watch(savingGoalsProvider).value ?? const <SavingGoal>[];
    final entries = ref.watch(financeEntriesProvider).value ?? const <FinanceEntry>[];
    final repository = ref.read(financeRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Geld auf ein Sparziel zu legen senkt den Kontostand. Hier siehst du, wie viel schon zurückliegt.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => _editGoal(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Neues Sparziel'),
          ),
        ),
        const SizedBox(height: 8),
        if (goals.isEmpty) const EmptyState(icon: Icons.flag_outlined, message: 'Noch keine Sparziele.'),
        for (final goal in goals)
          Builder(builder: (context) {
            final saved = savedFor(goal.id, entries);
            final percent = goal.targetCents <= 0 ? 0 : (saved * 100 ~/ goal.targetCents);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(goal.name, style: theme.textTheme.titleMedium)),
                        PopupMenuButton<String>(
                          onSelected: (value) => value == 'edit'
                              ? _editGoal(context, ref, goal: goal)
                              : _deleteGoal(context, ref, goal, saved),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                            PopupMenuItem(value: 'delete', child: Text('Löschen')),
                          ],
                        ),
                      ],
                    ),
                    BudgetBar(value: saved, limit: goal.targetCents, color: incomeColor(context)),
                    const SizedBox(height: 6),
                    Text(
                      '${formatCents(saved)} von ${formatCents(goal.targetCents)} ($percent %)'
                      '${goal.targetDate == null ? '' : ' · bis ${formatDate(goal.targetDate!)}'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            final cents = await askAmount(context, title: 'Einzahlen auf ${goal.name}');
                            if (cents != null) await repository.deposit(goal.id, cents, goalName: goal.name);
                          },
                          child: const Text('Einzahlen'),
                        ),
                        TextButton(
                          onPressed: saved <= 0
                              ? null
                              : () async {
                                  final cents = await askAmount(context, title: 'Entnehmen aus ${goal.name}');
                                  if (cents != null) {
                                    await repository.withdraw(goal.id, cents > saved ? saved : cents, goalName: goal.name);
                                  }
                                },
                          child: const Text('Entnehmen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.goal});

  final SavingGoal? goal;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.goal?.name ?? '');
  late final TextEditingController _target = TextEditingController(
    text: widget.goal == null ? '' : formatCents(widget.goal!.targetCents).replaceAll(' €', '').replaceAll('.', ''),
  );
  late DateTime? _date = widget.goal?.targetDate;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  void _submit() {
    final target = parseCents(_target.text)?.abs();
    if (_name.text.trim().isEmpty || target == null || target == 0) {
      setState(() => _error = 'Bitte Name und Zielbetrag eingeben.');
      return;
    }
    Navigator.of(context).pop((name: _name.text.trim(), target: target, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.goal == null ? 'Neues Sparziel' : 'Sparziel bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'z. B. Urlaub'),
          ),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Zielbetrag in €', errorText: _error),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bis wann?'),
            subtitle: Text(_date == null ? 'Ohne Datum' : formatDate(_date!)),
            trailing: _date == null
                ? const Icon(Icons.event)
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _date = null)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}
