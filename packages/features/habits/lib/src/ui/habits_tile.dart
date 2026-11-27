import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../habit_math.dart';
import '../providers.dart';

/// Dashboard-Kachel: heutige Habits zum direkten Abhaken.
class HabitsTile extends ConsumerWidget {
  const HabitsTile({super.key, required this.onOpen, this.clock, this.maxItems = 6});

  final VoidCallback onOpen;
  final DateTime Function()? clock;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly((clock ?? DateTime.now)());
    final habits = ref.watch(habitsProvider).value ?? const [];
    final done = doneDaysByHabit(ref.watch(habitChecksProvider).value ?? const []);
    final due = [for (final habit in habits) if (habit.isDueOn(today)) habit];
    final finished = due.where((habit) => done[habit.id]?.contains(isoDate(today)) ?? false).length;

    return SectionCard(
      title: 'Habits heute',
      icon: Icons.repeat,
      action: TextButton(onPressed: onOpen, child: const Text('Alle')),
      child: due.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(habits.isEmpty ? 'Noch keine Habits.' : 'Heute ist kein Habit dran.'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$finished von ${due.length} erledigt', style: Theme.of(context).textTheme.bodySmall),
                for (final habit in due.take(maxItems))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: done[habit.id]?.contains(isoDate(today)) ?? false,
                    title: Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    secondary: CircleAvatar(radius: 6, backgroundColor: tagColor(habit.colorIndex)),
                    onChanged: (value) => ref.read(habitRepositoryProvider).setDone(habit.id, today, value ?? false),
                  ),
              ],
            ),
    );
  }
}
