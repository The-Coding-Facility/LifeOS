import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_daily_report/lifeos_daily_report.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_kitchen/lifeos_kitchen.dart';

import '../model.dart';
import '../providers.dart';
import '../sport_math.dart';
import 'plan_editor_page.dart';
import 'playback_page.dart';

/// Zahl mit Komma, höchstens eine Nachkommastelle.
String formatNumber(double value) => formatAmount(value, maxDecimals: 1);

/// Schlafdauer je Tag aus dem Daily Report (Stunden).
Map<String, double> sleepFromReports(List<DailyReport> reports) => {
      for (final report in reports)
        if (report.sleep != null) isoDate(report.date): report.sleep!.inMinutes / 60,
    };

/// Sport mit den Reitern Übersicht, Tracker, Über mich, Übungen, Pläne.
class SportPage extends ConsumerWidget {
  const SportPage({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly((clock ?? DateTime.now)());
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sport'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Übersicht'),
              Tab(text: 'Tracker'),
              Tab(text: 'Über mich'),
              Tab(text: 'Übungen'),
              Tab(text: 'Pläne'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(today: today),
            _TrackerTab(today: today),
            _BodyTab(today: today),
            const _ExercisesTab(),
            const _PlansTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Übersicht

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.today});

  final DateTime today;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  var _measure = Measure.weight;
  var _days = 90;
  String? _exerciseId;
  var _metric = ResultMetric.weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = ref.watch(bodyEntriesProvider).value ?? const <BodyEntry>[];
    final reports = ref.watch(dailyReportsProvider).value ?? const <DailyReport>[];
    final workouts = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final plans = {for (final p in ref.watch(trainingPlansProvider).value ?? const <TrainingPlan>[]) p.id: p};
    final from = DateTime(widget.today.year, widget.today.month, widget.today.day - _days);
    final series = measureSeries(body, _measure, from: from, sleepFallback: sleepFromReports(reports));
    final exerciseId = exercises.any((e) => e.id == _exerciseId)
        ? _exerciseId
        : (exercises.isEmpty ? null : exercises.first.id);
    final progress = exerciseId == null ? const <SeriesPoint>[] : exerciseSeries(workouts, exerciseId, _metric);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _IntakeCard(today: widget.today),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Körperdaten',
          icon: Icons.monitor_weight_outlined,
          action: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 90, label: Text('90 T')), ButtonSegment(value: 365, label: Text('1 J'))],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<Measure>(
                value: _measure,
                isExpanded: true,
                items: [for (final m in Measure.values) DropdownMenuItem(value: m, child: Text('${m.label} (${m.unit})'))],
                onChanged: (m) => setState(() => _measure = m ?? _measure),
              ),
              LineChartView(
                values: [for (final p in series) (p.value * 10).round()],
                formatValue: (v) => '${formatNumber(v / 10)} ${_measure.unit}',
                startLabel: series.isEmpty ? null : formatDateShort(series.first.date),
                endLabel: series.isEmpty ? null : formatDateShort(series.last.date),
              ),
              if (series.isNotEmpty)
                Text('Aktuell: ${formatNumber(series.last.value)} ${_measure.unit}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Fortschritt einer Übung',
          icon: Icons.trending_up,
          child: exercises.isEmpty
              ? const Text('Leg zuerst Übungen im Katalog an.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: exerciseId,
                            isExpanded: true,
                            items: [for (final e in exercises) DropdownMenuItem(value: e.id, child: Text(e.name))],
                            onChanged: (id) => setState(() => _exerciseId = id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<ResultMetric>(
                          value: _metric,
                          items: [for (final m in ResultMetric.values) DropdownMenuItem(value: m, child: Text(m.label))],
                          onChanged: (m) => setState(() => _metric = m ?? _metric),
                        ),
                      ],
                    ),
                    LineChartView(
                      values: [for (final p in progress) (p.value * 10).round()],
                      formatValue: (v) => '${formatNumber(v / 10)} ${_metric.unit}',
                      startLabel: progress.isEmpty ? null : formatDateShort(progress.first.date),
                      endLabel: progress.isEmpty ? null : formatDateShort(progress.last.date),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text('Letzte Trainings', style: theme.textTheme.titleMedium),
        if (workouts.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Trainings.')),
        for (final workout in workouts.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fitness_center),
            title: Text(plans[workout.planId]?.name ?? 'Training'),
            subtitle: Text('${formatDateShort(workout.startedAt)} ${formatTime(workout.startedAt)} · '
                '${workout.duration.inMinutes} Min · ${workout.results.length} Übungen notiert'),
          ),
      ],
    );
  }
}

class _IntakeCard extends ConsumerWidget {
  const _IntakeCard({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intake = intakeOn(ref.watch(nutritionLogsProvider).value ?? const <NutritionLog>[], today);
    final goals = ref.watch(sportGoalsProvider).value ?? const IntakeGoals();
    return SectionCard(
      title: 'Heute',
      icon: Icons.restaurant_outlined,
      child: Column(
        children: [
          IntakeRow(label: 'kcal', value: intake.kcal, goal: goals.kcal, unit: ''),
          IntakeRow(label: 'Protein', value: intake.protein, goal: goals.protein, unit: 'g'),
          IntakeRow(label: 'Fett', value: intake.fat, goal: goals.fat, unit: 'g'),
          IntakeRow(label: 'Wasser', value: intake.waterMl, goal: goals.waterMl, unit: 'ml'),
        ],
      ),
    );
  }
}

/// Eine Zeile „kcal 1.850 / 2.000“ mit Balken.
class IntakeRow extends StatelessWidget {
  const IntakeRow({super.key, required this.label, required this.value, required this.goal, required this.unit});

  final String label;
  final double value;
  final double? goal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = goal == null
        ? '${formatNumber(value)} $unit'
        : '${formatNumber(value)} / ${formatNumber(goal!)} $unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label)),
          Expanded(
            child: goal == null || goal! <= 0
                ? const SizedBox()
                : BudgetBar(value: value.round(), limit: goal!.round(), color: const Color(0xFF2E9E6B)),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(text.trim(), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Tracker

class _TrackerTab extends ConsumerStatefulWidget {
  const _TrackerTab({required this.today});

  final DateTime today;

  @override
  ConsumerState<_TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<_TrackerTab> {
  late DateTime _day = widget.today;

  Future<void> _addEntry() async {
    final result = await showDialog<Map<String, double>>(context: context, builder: (_) => const _NutritionDialog());
    if (result == null || !mounted) return;
    await ref.read(sportRepositoryProvider).addNutrition(
          _day,
          label: 'Eintrag',
          kcal: result['kcal'] ?? 0,
          protein: result['protein'] ?? 0,
          fat: result['fat'] ?? 0,
          waterMl: result['water'] ?? 0,
        );
  }

  Future<void> _addRecipe(List<Recipe> recipes, Map<String, Ingredient> ingredients) async {
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Noch keine Rezepte in der Küche.')));
      return;
    }
    final recipe = await showDialog<Recipe>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Welche Portion?'),
        children: [
          for (final recipe in recipes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(recipe),
              child: Text(
                '${recipe.title} · ${perServing(recipeNutrition(recipe, ingredients), recipe.servings).kcal.round()} kcal',
              ),
            ),
        ],
      ),
    );
    if (recipe == null || !mounted) return;
    final portion = perServing(recipeNutrition(recipe, ingredients), recipe.servings);
    await ref.read(sportRepositoryProvider).addNutrition(
          _day,
          label: recipe.title,
          kcal: portion.kcal,
          protein: portion.protein,
          fat: portion.fat,
        );
  }

  Future<void> _editGoals(IntakeGoals goals) async {
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (_) => _NutritionDialog(
        title: 'Tagesziele',
        initial: {
          if (goals.kcal != null) 'kcal': goals.kcal!,
          if (goals.protein != null) 'protein': goals.protein!,
          if (goals.fat != null) 'fat': goals.fat!,
          if (goals.waterMl != null) 'water': goals.waterMl!,
        },
      ),
    );
    if (result == null) return;
    double? goal(String key) => (result[key] ?? 0) > 0 ? result[key] : null;
    await ref.read(sportRepositoryProvider).setGoals(
          IntakeGoals(kcal: goal('kcal'), protein: goal('protein'), fat: goal('fat'), waterMl: goal('water')),
        );
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(nutritionLogsProvider).value ?? const <NutritionLog>[];
    final goals = ref.watch(sportGoalsProvider).value ?? const IntakeGoals();
    final intake = intakeOn(logs, _day);
    final dayLogs = [for (final log in logs) if (isoDate(log.date) == isoDate(_day)) log];
    final repository = ref.read(sportRepositoryProvider);
    final isToday = isoDate(_day) == isoDate(widget.today);
    // Beobachten hält die Küchen-Daten bereit (Riverpod pausiert sonst).
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final ingredients = {for (final i in ref.watch(ingredientsProvider).value ?? const <Ingredient>[]) i.id: i};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day - 1)),
            ),
            Expanded(child: Text(isToday ? 'Heute' : formatDateLong(_day), textAlign: TextAlign.center)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday ? null : () => setState(() => _day = DateTime(_day.year, _day.month, _day.day + 1)),
            ),
          ],
        ),
        IntakeRow(label: 'kcal', value: intake.kcal, goal: goals.kcal, unit: ''),
        IntakeRow(label: 'Protein', value: intake.protein, goal: goals.protein, unit: 'g'),
        IntakeRow(label: 'Fett', value: intake.fat, goal: goals.fat, unit: 'g'),
        IntakeRow(label: 'Wasser', value: intake.waterMl, goal: goals.waterMl, unit: 'ml'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ml in [250, 500])
              FilledButton.tonalIcon(
                onPressed: () => repository.addNutrition(_day, label: 'Wasser', waterMl: ml.toDouble()),
                icon: const Icon(Icons.water_drop_outlined),
                label: Text('+$ml ml'),
              ),
            OutlinedButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add), label: const Text('Eintrag')),
            OutlinedButton.icon(
              onPressed: () => _addRecipe(recipes, ingredients), icon: const Icon(Icons.restaurant_menu), label: const Text('Rezeptportion')),
            TextButton.icon(onPressed: () => _editGoals(goals), icon: const Icon(Icons.flag_outlined), label: const Text('Ziele')),
          ],
        ),
        const SizedBox(height: 12),
        for (final log in dayLogs.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(log.label.isEmpty ? 'Eintrag' : log.label),
            subtitle: Text([
              if (log.kcal > 0) '${log.kcal.round()} kcal',
              if (log.protein > 0) '${formatNumber(log.protein)} g Protein',
              if (log.fat > 0) '${formatNumber(log.fat)} g Fett',
              if (log.waterMl > 0) '${log.waterMl.round()} ml Wasser',
            ].join(' · ')),
            trailing: IconButton(
              tooltip: 'Entfernen',
              icon: const Icon(Icons.close),
              onPressed: () => repository.deleteNutrition(log.id),
            ),
          ),
      ],
    );
  }
}

class _NutritionDialog extends StatefulWidget {
  const _NutritionDialog({this.title = 'Eintrag', this.initial = const {}});

  final String title;
  final Map<String, double> initial;

  @override
  State<_NutritionDialog> createState() => _NutritionDialogState();
}

class _NutritionDialogState extends State<_NutritionDialog> {
  static const _fields = {'kcal': 'kcal', 'protein': 'Protein (g)', 'fat': 'Fett (g)', 'water': 'Wasser (ml)'};
  late final _controllers = {
    for (final key in _fields.keys)
      key: TextEditingController(text: widget.initial[key] == null ? '' : formatNumber(widget.initial[key]!)),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final MapEntry(:key, :value) in _fields.entries)
            TextField(
              controller: _controllers[key],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: value),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            for (final MapEntry(:key, :value) in _controllers.entries) key: parseAmount(value.text) ?? 0,
          }),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Über mich

class _BodyTab extends ConsumerStatefulWidget {
  const _BodyTab({required this.today});

  final DateTime today;

  @override
  ConsumerState<_BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends ConsumerState<_BodyTab> {
  late DateTime _day = widget.today;
  final _controllers = {for (final m in Measure.values) m: TextEditingController()};
  String? _filledFor;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(List<BodyEntry> entries) {
    final key = isoDate(_day);
    if (_filledFor == key) return;
    _filledFor = key;
    final entry = entries.where((e) => isoDate(e.date) == key).firstOrNull;
    for (final measure in Measure.values) {
      final value = entry?.values[measure];
      _controllers[measure]!.text = value == null ? '' : formatNumber(value);
    }
  }

  Future<void> _save() async {
    await ref.read(sportRepositoryProvider).saveBody(_day, {
      for (final measure in Measure.values) measure: parseAmount(_controllers[measure]!.text),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Körperdaten für ${formatDate(_day)} gespeichert')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(bodyEntriesProvider).value;
    if (entries != null) _fill(entries);
    final reports = ref.watch(dailyReportsProvider).value ?? const <DailyReport>[];
    final reportSleep = sleepFromReports(reports)[isoDate(_day)];
    final isToday = isoDate(_day) == isoDate(widget.today);

    void changeDay(int delta) => setState(() {
          _day = DateTime(_day.year, _day.month, _day.day + delta);
          _filledFor = null;
        });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => changeDay(-1)),
            Expanded(child: Text(isToday ? 'Heute' : formatDateLong(_day), textAlign: TextAlign.center)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: isToday ? null : () => changeDay(1)),
          ],
        ),
        Text('Alles optional. Einmal pro Tag reicht.', style: theme.textTheme.bodySmall),
        for (final measure in Measure.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: _controllers[measure],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: measure.label,
                suffixText: measure.unit,
                helperText: measure == Measure.sleepHours && reportSleep != null && _controllers[measure]!.text.isEmpty
                    ? 'Aus dem Daily Report: ${formatNumber(reportSleep)} h'
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Speichern')),
      ],
    );
  }
}

// ---------------------------------------------------------------- Übungen

class _ExercisesTab extends ConsumerStatefulWidget {
  const _ExercisesTab();

  @override
  ConsumerState<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<_ExercisesTab> {
  var _query = '';
  ExerciseCategory? _category;

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final e in exercises)
        if ((_category == null || e.category == _category) && (query.isEmpty || e.name.toLowerCase().contains(query))) e,
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Übung',
        onPressed: () => editExercise(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Übung suchen'),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(label: const Text('Alle'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
              for (final category in ExerciseCategory.values)
                ChoiceChip(
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (selected) => setState(() => _category = selected ? category : null),
                ),
            ],
          ),
          if (visible.isEmpty) const EmptyState(icon: Icons.sports_gymnastics, message: 'Keine Übungen.'),
          for (final exercise in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(exercise.category == ExerciseCategory.strength ? Icons.fitness_center : Icons.directions_run),
              title: Text(exercise.name),
              subtitle: Text([exercise.category.label, if (exercise.description.isNotEmpty) exercise.description].join(' · ')),
              onTap: () => editExercise(context, ref, exercise: exercise),
            ),
        ],
      ),
    );
  }
}

/// Dialog für eine Übung.
Future<void> editExercise(BuildContext context, WidgetRef ref, {Exercise? exercise}) async {
  final name = TextEditingController(text: exercise?.name ?? '');
  final description = TextEditingController(text: exercise?.description ?? '');
  var category = exercise?.category ?? ExerciseCategory.strength;
  final action = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(exercise == null ? 'Neue Übung' : 'Übung bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, autofocus: exercise == null, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            SegmentedButton<ExerciseCategory>(
              showSelectedIcon: false,
              segments: [for (final c in ExerciseCategory.values) ButtonSegment(value: c, label: Text(c.label))],
              selected: {category},
              onSelectionChanged: (s) => setState(() => category = s.first),
            ),
            TextField(
              controller: description,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
            ),
          ],
        ),
        actions: [
          if (exercise != null)
            TextButton(onPressed: () => Navigator.of(context).pop('delete'), child: const Text('Löschen')),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.of(context).pop('save');
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
  final repository = ref.read(sportRepositoryProvider);
  if (action == 'save') {
    if (exercise == null) {
      await repository.addExercise(name: name.text, category: category, description: description.text);
    } else {
      await repository.updateExercise(exercise, name: name.text, category: category, description: description.text);
    }
  } else if (action == 'delete' && exercise != null) {
    await repository.deleteExercise(exercise.id);
  }
  name.dispose();
  description.dispose();
}

// ------------------------------------------------------------------ Pläne

class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(trainingPlansProvider).value ?? const <TrainingPlan>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openPlanEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Plan'),
      ),
      body: plans.isEmpty
          ? const EmptyState(icon: Icons.list_alt, message: 'Noch keine Trainingspläne.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                for (final plan in plans)
                  Card(
                    child: ListTile(
                      title: Text(plan.name),
                      subtitle: Text('${plan.kind.label} · ${plan.steps.length} Übungen · '
                          'ca. ${(plan.totalDuration.inSeconds / 60).ceil()} Min'),
                      onTap: () => openPlanEditor(context, plan: plan),
                      trailing: IconButton.filled(
                        tooltip: 'Starten',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: plan.steps.isEmpty ? null : () => openPlayback(context, plan.id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
