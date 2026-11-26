import 'package:flutter/material.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../occurrences.dart';
import 'event_chip.dart';

/// Erster Tag des Monatsrasters: der Montag in der Woche des Monatsersten.
DateTime monthGridStart(DateTime month) {
  final first = DateTime(month.year, month.month);
  return DateTime(first.year, first.month, first.day - (first.weekday - 1));
}

/// Monatsansicht: 6 Wochen à 7 Tage. Termine lassen sich per langem
/// Drücken auf einen anderen Tag ziehen.
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.today,
    required this.occurrences,
    required this.tags,
    required this.onTapDay,
    required this.onOpen,
    required this.onDropOnDay,
  });

  final DateTime month;
  final DateTime today;

  /// Vorkommen im sichtbaren Raster (42 Tage ab [monthGridStart]).
  final List<Occurrence> occurrences;
  final Map<String, TagItem> tags;
  final ValueChanged<DateTime> onTapDay;
  final ValueChanged<Occurrence> onOpen;
  final void Function(Occurrence occurrence, DateTime day) onDropOnDay;

  static const int maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = monthGridStart(month);
    return Column(
      children: [
        Row(
          children: [
            for (final name in germanWeekdaysShort)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(name, textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                ),
              ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var weekday = 0; weekday < 7; weekday++)
                        Expanded(
                          child: _DayCell(
                            day: DateTime(start.year, start.month, start.day + week * 7 + weekday),
                            inMonth: DateTime(start.year, start.month, start.day + week * 7 + weekday).month ==
                                month.month,
                            today: today,
                            occurrences: occurrences,
                            tags: tags,
                            onTap: onTapDay,
                            onOpen: onOpen,
                            onDrop: onDropOnDay,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.occurrences,
    required this.tags,
    required this.onTap,
    required this.onOpen,
    required this.onDrop,
  });

  final DateTime day;
  final bool inMonth;
  final DateTime today;
  final List<Occurrence> occurrences;
  final Map<String, TagItem> tags;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<Occurrence> onOpen;
  final void Function(Occurrence occurrence, DateTime day) onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = isoDate(day) == isoDate(today);
    final dayOccurrences = [for (final o in occurrences) if (o.coversDay(day)) o];
    final visible = dayOccurrences.take(MonthView.maxChips).toList();
    final hidden = dayOccurrences.length - visible.length;

    return DragTarget<Occurrence>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data, day),
      builder: (context, candidates, _) {
        return InkWell(
          onTap: () => onTap(day),
          child: Container(
            decoration: BoxDecoration(
              color: candidates.isNotEmpty
                  ? scheme.primaryContainer
                  : (inMonth ? null : scheme.surfaceContainerLow),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: isToday
                        ? BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10))
                        : null,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isToday
                            ? scheme.onPrimary
                            : (inMonth ? scheme.onSurface : scheme.onSurfaceVariant),
                        fontWeight: isToday ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  // Scrollansicht ohne Scrollen: schneidet ab, was nicht passt,
                  // ohne Überlauf-Fehler.
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final occurrence in visible)
                          DraggableOccurrence(
                            occurrence: occurrence,
                            child: GestureDetector(
                              onTap: () => onOpen(occurrence),
                              child: EventChip(
                                occurrence: occurrence,
                                color: occurrenceColor(context, occurrence, tags),
                              ),
                            ),
                          ),
                        if (hidden > 0)
                          Text('+$hidden', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
