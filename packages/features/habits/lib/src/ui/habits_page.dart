import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../habit_math.dart';
import '../model.dart';
import '../providers.dart';

/// Habits: heute abhaken, Woche im Überblick, anlegen und bearbeiten.
class HabitsPage extends ConsumerStatefulWidget {
  const HabitsPage({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  ConsumerState<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends ConsumerState<HabitsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late DateTime _weekStart = _mondayOf(_today);

  DateTime get _today => dateOnly((widget.clock ?? DateTime.now)());

  static DateTime _mondayOf(DateTime day) => DateTime(day.year, day.month, day.day - (day.weekday - 1));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final habits = ref.watch(habitsProvider);
    final done = doneDaysByHabit(ref.watch(habitChecksProvider).value ?? const []);
    // Erst beim Antippen lesen, damit die Seite auch ohne Datenbank baut.
    Future<void> setDone(String habitId, DateTime date, bool value) =>
        ref.read(habitRepositoryProvider).setDone(habitId, date, value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Heute'), Tab(text: 'Woche')]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editHabit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Neues Habit'),
      ),
      body: habits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.repeat,
              message: 'Noch keine Habits. Leg eins an, z. B. „10 Minuten lesen“ oder „Dehnen“.',
            );
          }
          return TabBarView(
            controller: _tabs,
            children: [
              _TodayList(habits: all, done: done, today: today, repositorySetDone: setDone),
              _WeekGrid(
                habits: all,
                done: done,
                today: today,
                weekStart: _weekStart,
                onWeek: (delta) => setState(
                  () => _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * delta),
                ),
                setDone: setDone,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayList extends ConsumerWidget {
  const _TodayList({required this.habits, required this.done, required this.today, required this.repositorySetDone});

  final List<Habit> habits;
  final Map<String, Set<String>> done;
  final DateTime today;
  final Future<void> Function(String habitId, DateTime date, bool done) repositorySetDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = [for (final habit in habits) if (habit.isDueOn(today)) habit];
    final notDue = [for (final habit in habits) if (!habit.isDueOn(today)) habit];
    final finished = due.where((habit) => done[habit.id]?.contains(isoDate(today)) ?? false).length;

    Widget tile(Habit habit, {required bool active}) {
      final days = done[habit.id] ?? const <String>{};
      final isDone = days.contains(isoDate(today));
      final streak = habitStreak(habit, days, today);
      final rate = (completionRate(habit, days, today) * 100).round();
      return CheckboxListTile(
        value: isDone,
        onChanged: active ? (value) => repositorySetDone(habit.id, today, value ?? false) : null,
        secondary: CircleAvatar(radius: 8, backgroundColor: tagColor(habit.colorIndex)),
        title: Text(habit.name),
        subtitle: Text('${habit.scheduleText} · Serie: $streak · 30 Tage: $rate %'),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            due.isEmpty ? 'Heute ist kein Habit dran.' : '$finished von ${due.length} erledigt',
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final habit in due)
          GestureDetector(onLongPress: () => editHabit(context, ref, habit: habit), child: tile(habit, active: true)),
        if (notDue.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Heute nicht dran', style: theme.textTheme.labelLarge),
          ),
          for (final habit in notDue)
            GestureDetector(onLongPress: () => editHabit(context, ref, habit: habit), child: tile(habit, active: false)),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Lange drücken zum Bearbeiten.', style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({
    required this.habits,
    required this.done,
    required this.today,
    required this.weekStart,
    required this.onWeek,
    required this.setDone,
  });

  final List<Habit> habits;
  final Map<String, Set<String>> done;
  final DateTime today;
  final DateTime weekStart;
  final ValueChanged<int> onWeek;
  final Future<void> Function(String habitId, DateTime date, bool done) setDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final days = [for (var i = 0; i < 7; i++) DateTime(weekStart.year, weekStart.month, weekStart.day + i)];
    final end = days.last;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Row(
          children: [
            IconButton(tooltip: 'Vorige Woche', icon: const Icon(Icons.chevron_left), onPressed: () => onWeek(-1)),
            Expanded(
              child: Text(
                '${weekStart.day}.${weekStart.month}. – ${end.day}.${end.month}.${end.year}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(tooltip: 'Nächste Woche', icon: const Icon(Icons.chevron_right), onPressed: () => onWeek(1)),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 8,
            horizontalMargin: 8,
            columns: [
              const DataColumn(label: Text('Habit')),
              for (final day in days)
                DataColumn(
                  label: Text(
                    '${germanWeekdaysShort[day.weekday - 1]}\n${day.day}.',
                    textAlign: TextAlign.center,
                    style: isoDate(day) == isoDate(today) ? TextStyle(color: theme.colorScheme.primary) : null,
                  ),
                ),
            ],
            rows: [
              for (final habit in habits)
                DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(habit.name, overflow: TextOverflow.ellipsis),
                      ),
                      onLongPress: () => editHabit(context, ref, habit: habit),
                    ),
                    for (final day in days)
                      DataCell(
                        !habit.isDueOn(day)
                            ? const Center(child: Text('–'))
                            : Checkbox(
                                value: done[habit.id]?.contains(isoDate(day)) ?? false,
                                onChanged: day.isAfter(today) ? null : (value) => setDone(habit.id, day, value ?? false),
                              ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog zum Anlegen oder Bearbeiten eines Habits.
Future<void> editHabit(BuildContext context, WidgetRef ref, {Habit? habit}) async {
  final result = await showDialog<_HabitResult>(
    context: context,
    builder: (context) => _HabitDialog(habit: habit),
  );
  if (result == null) return;
  final repository = ref.read(habitRepositoryProvider);
  switch (result.action) {
    case _HabitAction.save:
      if (habit == null) {
        await repository.create(result.name, colorIndex: result.color, weekdays: result.weekdays);
      } else {
        await repository.update(habit.id, name: result.name, colorIndex: result.color, weekdays: result.weekdays);
      }
    case _HabitAction.archive:
      if (habit != null) await repository.archive(habit.id);
    case _HabitAction.delete:
      if (habit != null) await repository.delete(habit.id);
  }
}

enum _HabitAction { save, archive, delete }

class _HabitResult {
  const _HabitResult(this.action, {this.name = '', this.color = 0, this.weekdays = const {}});

  final _HabitAction action;
  final String name;
  final int color;
  final Set<int> weekdays;
}

class _HabitDialog extends StatefulWidget {
  const _HabitDialog({this.habit});

  final Habit? habit;

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  late final _name = TextEditingController(text: widget.habit?.name ?? '');
  late var _color = widget.habit?.colorIndex ?? 0;
  late var _daily = widget.habit?.daily ?? true;
  late var _weekdays = <int>{...?widget.habit?.weekdays};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      _HabitResult(
        _HabitAction.save,
        name: _name.text.trim(),
        color: _color,
        weekdays: _daily || _weekdays.isEmpty ? const {} : _weekdays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.habit == null ? 'Neues Habit' : 'Habit bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.habit == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Jeden Tag')),
                ButtonSegment(value: false, label: Text('Bestimmte Tage')),
              ],
              selected: {_daily},
              onSelectionChanged: (selection) => setState(() => _daily = selection.first),
            ),
            if (!_daily) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(germanWeekdaysShort[day - 1]),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() {
                        _weekdays = {..._weekdays};
                        selected ? _weekdays.add(day) : _weekdays.remove(day);
                      }),
                    ),
                ],
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
        if (widget.habit != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(const _HabitResult(_HabitAction.delete)),
            child: const Text('Löschen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(const _HabitResult(_HabitAction.archive)),
            child: const Text('Archivieren'),
          ),
        ],
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
