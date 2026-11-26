import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../occurrences.dart';
import '../providers.dart';

/// Dashboard-Kachel: Termine von heute, sonst der nächste Termin.
class CalendarDashboardTile extends ConsumerWidget {
  const CalendarDashboardTile({super.key, required this.onOpen, this.maxItems = 5, this.clock});

  final VoidCallback onOpen;
  final int maxItems;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final now = (clock ?? DateTime.now)();
    final today = dateOnly(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Heute im Kalender',
      icon: Icons.calendar_month_outlined,
      action: TextButton(onPressed: onOpen, child: const Text('Kalender')),
      child: events.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text('Fehler: $error'),
        data: (all) {
          final todays = expandAll(all, today, tomorrow);
          if (todays.isEmpty) {
            final upcoming = expandAll(all, tomorrow, DateTime(today.year, today.month, today.day + 15));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                upcoming.isEmpty
                    ? 'Heute keine Termine.'
                    : 'Heute keine Termine. Nächster: ${formatDateShort(upcoming.first.start)} '
                        '${upcoming.first.event.title}',
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final occurrence in todays.take(maxItems))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          occurrence.allDay ? 'ganzt.' : formatTime(occurrence.start),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Expanded(
                        child: Text(occurrence.event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              if (todays.length > maxItems)
                Text('und ${todays.length - maxItems} weitere', style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
