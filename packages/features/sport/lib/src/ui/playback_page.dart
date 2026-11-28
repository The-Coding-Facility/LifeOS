import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';

import '../model.dart';
import '../playback.dart';
import '../providers.dart';

/// Öffnet den Abspielmodus für einen Plan.
Future<void> openPlayback(BuildContext context, String planId) => Navigator.of(context).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PlaybackPage(planId: planId)),
    );

/// `65` → `1:05`.
String formatCountdown(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Spielt einen Trainingsplan ab: Countdown, Ton beim Wechsel, danach
/// Werte notieren und speichern.
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  final _startedAt = DateTime.now();
  TrainingPlayback? _playback;
  Timer? _timer;
  DateTime? _lastTick;
  var _finished = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(TrainingPlan plan) {
    _playback = TrainingPlayback(plan.steps);
    _lastTick = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
  }

  void _onTick() {
    final playback = _playback;
    if (playback == null || !mounted) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTick ?? now);
    _lastTick = now;
    final before = playback.remaining.inSeconds;
    final changed = playback.tick(elapsed);
    if (changed) SystemSound.play(SystemSoundType.alert);
    if (playback.isDone) {
      _finish();
    } else if (changed || playback.remaining.inSeconds != before) {
      setState(() {});
    }
  }

  void _next() {
    final playback = _playback;
    if (playback == null) return;
    setState(() => playback.next());
    if (playback.isDone) _finish();
  }

  void _finish() {
    _timer?.cancel();
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(trainingPlansProvider);
    final exercises = {for (final e in ref.watch(exercisesProvider).value ?? const <Exercise>[]) e.id: e};
    final plan = plans.value?.where((p) => p.id == widget.planId).firstOrNull;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training')),
        body: Center(
          child: plans.isLoading ? const CircularProgressIndicator() : const Text('Dieser Plan existiert nicht mehr.'),
        ),
      );
    }
    if (_playback == null && !_finished) {
      if (plan.steps.isEmpty) {
        _finished = true;
      } else {
        _start(plan);
      }
    }

    if (_finished) {
      return _ResultPage(plan: plan, exercises: exercises, startedAt: _startedAt);
    }
    return _runner(context, plan, exercises);
  }

  Widget _runner(BuildContext context, TrainingPlan plan, Map<String, Exercise> exercises) {
    final theme = Theme.of(context);
    final playback = _playback!;
    final step = playback.currentStep!;
    final exercise = exercises[step.exerciseId];
    final isRest = playback.phase == PlaybackPhase.rest;
    final nextStep = playback.stepIndex + 1 < plan.steps.length ? plan.steps[playback.stepIndex + 1] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [TextButton(onPressed: _finish, child: const Text('Beenden'))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Übung ${playback.stepIndex + 1} von ${plan.steps.length}', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (playback.stepIndex + (isRest ? 1 : 0)) / plan.steps.length),
              const Spacer(),
              Text(
                isRest ? 'Pause' : (exercise?.name ?? 'Gelöschte Übung'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              if (isRest && nextStep != null)
                Text(
                  'Gleich: ${exercises[nextStep.exerciseId]?.name ?? 'Gelöschte Übung'}',
                  textAlign: TextAlign.center,
                ),
              if (!isRest && (exercise?.description.isNotEmpty ?? false))
                Text(exercise!.description, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Text(
                playback.waitsForUser ? 'Ohne Zeit' : formatCountdown(playback.remaining),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isRest ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    tooltip: 'Zurück',
                    iconSize: 32,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => setState(playback.previous),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    tooltip: playback.paused ? 'Weiter' : 'Pause',
                    iconSize: 48,
                    icon: Icon(playback.paused ? Icons.play_arrow : Icons.pause),
                    onPressed: playback.waitsForUser ? null : () => setState(playback.togglePause),
                  ),
                  const SizedBox(width: 16),
                  IconButton.outlined(
                    tooltip: 'Nächster Abschnitt',
                    iconSize: 32,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _next,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nach dem Training: Werte je Übung notieren und speichern.
class _ResultPage extends ConsumerStatefulWidget {
  const _ResultPage({required this.plan, required this.exercises, required this.startedAt});

  final TrainingPlan plan;
  final Map<String, Exercise> exercises;
  final DateTime startedAt;

  @override
  ConsumerState<_ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<_ResultPage> {
  late final Duration _duration = DateTime.now().difference(widget.startedAt);
  late final List<String> _exerciseIds = {for (final step in widget.plan.steps) step.exerciseId}.toList();
  final _controllers = <String, Map<ResultMetric, TextEditingController>>{};
  var _saving = false;

  static const _strengthMetrics = [ResultMetric.weight, ResultMetric.reps];
  static const _enduranceMetrics = [ResultMetric.distanceKm, ResultMetric.minutes, ResultMetric.avgPulse, ResultMetric.maxPulse];

  /// Die üblichen Werte der Übung zuerst; die übrigen stehen unter
  /// „Weitere Werte“.
  List<ResultMetric> _primaryFor(String exerciseId) =>
      widget.exercises[exerciseId]?.category == ExerciseCategory.endurance ? _enduranceMetrics : _strengthMetrics;

  List<ResultMetric> _secondaryFor(String exerciseId) {
    final primary = _primaryFor(exerciseId);
    return [for (final metric in ResultMetric.values) if (!primary.contains(metric)) metric];
  }

  TextEditingController _controller(String exerciseId, ResultMetric metric) =>
      (_controllers[exerciseId] ??= {})[metric] ??= TextEditingController();

  @override
  void dispose() {
    for (final group in _controllers.values) {
      for (final controller in group.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final results = <ExerciseResult>[];
    for (final id in _exerciseIds) {
      final values = <ResultMetric, double>{
        for (final metric in ResultMetric.values)
          if (parseAmount(_controller(id, metric).text) case final value?) metric: value,
      };
      if (values.isNotEmpty) results.add(ExerciseResult(exerciseId: id, values: values));
    }
    final navigator = Navigator.of(context);
    await ref.read(sportRepositoryProvider).saveWorkout(
          planId: widget.plan.id,
          startedAt: widget.startedAt,
          duration: _duration,
          results: results,
        );
    navigator.pop();
  }

  Widget _fields(String exerciseId, List<ResultMetric> metrics) => Wrap(
        spacing: 12,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: 130,
              child: TextField(
                controller: _controller(exerciseId, metric),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: metric.label, suffixText: metric.unit),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training geschafft'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Verwerfen')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${widget.plan.name} · ${_duration.inMinutes} Min', style: theme.textTheme.titleMedium),
          Text('Notiere, was du geschafft hast. Alles optional.', style: theme.textTheme.bodySmall),
          for (final id in _exerciseIds)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.exercises[id]?.name ?? 'Gelöschte Übung', style: theme.textTheme.titleSmall),
                    _fields(id, _primaryFor(id)),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Weitere Werte'),
                      children: [_fields(id, _secondaryFor(id))],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Training speichern'),
          ),
        ],
      ),
    );
  }
}
