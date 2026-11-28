import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model.dart';
import '../providers.dart';

/// Öffnet den Editor für einen neuen oder bestehenden Plan.
Future<void> openPlanEditor(BuildContext context, {TrainingPlan? plan}) => Navigator.of(context).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PlanEditorPage(plan: plan)),
    );

class _StepRow {
  _StepRow(this.exerciseId, int seconds, int rest)
      : seconds = TextEditingController(text: '$seconds'),
        rest = TextEditingController(text: '$rest');

  String exerciseId;
  final TextEditingController seconds;
  final TextEditingController rest;
}

/// Name, Art und Schritte eines Trainingsplans.
class PlanEditorPage extends ConsumerStatefulWidget {
  const PlanEditorPage({super.key, this.plan});

  final TrainingPlan? plan;

  @override
  ConsumerState<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends ConsumerState<PlanEditorPage> {
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late var _kind = widget.plan?.kind ?? PlanKind.strength;
  late final List<_StepRow> _steps = [
    for (final step in widget.plan?.steps ?? const <PlanStep>[]) _StepRow(step.exerciseId, step.seconds, step.restSeconds),
  ];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final step in _steps) {
      step.seconds.dispose();
      step.rest.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Bitte gib dem Plan einen Namen.');
      return;
    }
    final steps = [
      for (final row in _steps)
        PlanStep(
          exerciseId: row.exerciseId,
          seconds: int.tryParse(row.seconds.text.trim()) ?? 0,
          restSeconds: int.tryParse(row.rest.text.trim()) ?? 0,
        ),
    ];
    final repository = ref.read(sportRepositoryProvider);
    if (widget.plan == null) {
      await repository.addPlan(name: _name.text, kind: _kind, steps: steps);
    } else {
      await repository.updatePlan(widget.plan!, name: _name.text, kind: _kind, steps: steps);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final plan = widget.plan;
    if (plan == null) return;
    await ref.read(sportRepositoryProvider).deletePlan(plan.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final names = {for (final e in exercises) e.id: e.name};
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? 'Neuer Plan' : 'Plan bearbeiten'),
        actions: [
          if (widget.plan != null)
            IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.plan == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PlanKind>(
            showSelectedIcon: false,
            segments: [for (final k in PlanKind.values) ButtonSegment(value: k, label: Text(k.label))],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          Text('Übungen (Zeiten in Sekunden, 0 = ohne Countdown)', style: theme.textTheme.titleSmall),
          for (var i = 0; i < _steps.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Text('${i + 1}.', style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(names[_steps[i].exerciseId] ?? 'Gelöschte Übung', overflow: TextOverflow.ellipsis),
                    ),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _steps[i].seconds,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Übung', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _steps[i].rest,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ruhe', isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Nach oben',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0 ? null : () => setState(() => _steps.insert(i - 1, _steps.removeAt(i))),
                    ),
                    IconButton(
                      tooltip: 'Entfernen',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        final removed = _steps.removeAt(i);
                        removed.seconds.dispose();
                        removed.rest.dispose();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (exercises.isEmpty)
            const Text('Leg zuerst Übungen im Reiter „Übungen“ an.')
          else
            DropdownButton<String>(
              hint: const Text('Übung hinzufügen'),
              isExpanded: true,
              value: null,
              items: [for (final e in exercises) DropdownMenuItem(value: e.id, child: Text(e.name))],
              onChanged: (id) {
                if (id != null) setState(() => _steps.add(_StepRow(id, 60, 30)));
              },
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
