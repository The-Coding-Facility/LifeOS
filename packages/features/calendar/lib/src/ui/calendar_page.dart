import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model/event.dart';
import '../occurrences.dart';
import '../providers.dart';
import '../series_edit.dart';
import 'event_editor_page.dart';
import 'month_view.dart';
import 'series_choice.dart';
import 'time_grid_view.dart';

/// Ansicht des Kalenders.
enum CalendarViewMode { month, week, day }

/// ISO-Kalenderwoche von [date].
int isoWeekNumber(DateTime date) {
  final thursday = DateTime(date.year, date.month, date.day + (4 - date.weekday));
  final firstOfYear = DateTime(thursday.year);
  return calendarDaysBetween(firstOfYear, thursday) ~/ 7 + 1;
}

/// Kalender mit Monats-, Wochen- und Tagesansicht.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, this.clock});

  /// Für Tests; sonst die Systemzeit.
  final DateTime Function()? clock;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  var _mode = CalendarViewMode.month;
  late DateTime _focused;
  String? _tagFilter;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _focused = dateOnly(_now());
  }

  DateTime get _weekStart => DateTime(_focused.year, _focused.month, _focused.day - (_focused.weekday - 1));

  ({DateTime from, DateTime to}) get _range => switch (_mode) {
        CalendarViewMode.month => (
            from: monthGridStart(_focused),
            to: DateTime(monthGridStart(_focused).year, monthGridStart(_focused).month, monthGridStart(_focused).day + 42),
          ),
        CalendarViewMode.week => (
            from: _weekStart,
            to: DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7),
          ),
        CalendarViewMode.day => (
            from: _focused,
            to: DateTime(_focused.year, _focused.month, _focused.day + 1),
          ),
      };

  String get _title => switch (_mode) {
        CalendarViewMode.month => formatMonthYear(_focused),
        CalendarViewMode.week => 'KW ${isoWeekNumber(_focused)} · ${germanMonthsShort[_weekStart.month - 1]} ${_weekStart.year}',
        CalendarViewMode.day => formatDateLong(_focused),
      };

  void _step(int direction) {
    setState(() {
      _focused = switch (_mode) {
        CalendarViewMode.month => DateTime(_focused.year, _focused.month + direction),
        CalendarViewMode.week => DateTime(_focused.year, _focused.month, _focused.day + 7 * direction),
        CalendarViewMode.day => DateTime(_focused.year, _focused.month, _focused.day + direction),
      };
    });
  }

  void _openDay(DateTime day) {
    setState(() {
      _focused = dateOnly(day);
      _mode = CalendarViewMode.day;
    });
  }

  Future<void> _move(Occurrence occurrence, DateTime newStart) async {
    if (newStart == occurrence.start) return;
    final repository = ref.read(eventRepositoryProvider);
    final event = occurrence.event;
    final DateTime newEnd;
    if (occurrence.allDay) {
      final days = calendarDaysBetween(occurrence.start, occurrence.end) - 1;
      newEnd = DateTime(newStart.year, newStart.month, newStart.day + (days < 0 ? 0 : days));
    } else {
      newEnd = newStart.add(occurrence.end.difference(occurrence.start));
    }
    final moved = EventDraft.fromEvent(event, occurrenceStart: occurrence.start)
        .copyWith(start: newStart, end: newEnd);

    if (!event.isRecurring) {
      await repository.move(event.id, newStart);
      return;
    }
    if (!mounted) return;
    final choice = await askSeriesChoice(context, title: 'Termin verschieben');
    if (choice == null) return;
    if (choice == SeriesChoice.onlyThis) {
      await repository.detachOccurrence(event.id, occurrence.dateKey, moved);
    } else {
      await repository.update(
        event.id,
        applyToSeries(series: event, occurrenceStart: occurrence.start, edited: moved),
      );
    }
  }

  Future<void> _confirmDeleteTag(TagItem tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tag „${tag.name}“ löschen?'),
        content: const Text('Die Termine bleiben erhalten, nur der Tag verschwindet.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tagRepositoryProvider).delete(tag.id);
    if (_tagFilter == tag.id) setState(() => _tagFilter = null);
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final events = ref.watch(eventsProvider);
    final tags = ref.watch(tagsProvider(TagScope.calendar)).value ?? const <TagItem>[];
    final tagMap = {for (final tag in tags) tag.id: tag};
    final range = _range;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Zurück', icon: const Icon(Icons.chevron_left), onPressed: () => _step(-1)),
          TextButton(
            onPressed: () => setState(() => _focused = dateOnly(now)),
            child: const Text('Heute'),
          ),
          IconButton(tooltip: 'Weiter', icon: const Icon(Icons.chevron_right), onPressed: () => _step(1)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neuer Termin',
        onPressed: () {
          final start = _mode == CalendarViewMode.month || isoDate(_focused) != isoDate(now)
              ? DateTime(_focused.year, _focused.month, _focused.day, 9)
              : DateTime(now.year, now.month, now.day, now.hour + 1);
          openEventEditor(context, initialStart: start);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                SegmentedButton<CalendarViewMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: CalendarViewMode.month, label: Text('Monat')),
                    ButtonSegment(value: CalendarViewMode.week, label: Text('Woche')),
                    ButtonSegment(value: CalendarViewMode.day, label: Text('Tag')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) => setState(() => _mode = selection.first),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Alle'),
                  selected: _tagFilter == null,
                  onSelected: (_) => setState(() => _tagFilter = null),
                ),
                for (final tag in tags) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onLongPress: () => _confirmDeleteTag(tag),
                    child: ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: tagColor(tag.colorIndex), radius: 6),
                      label: Text(tag.name),
                      selected: _tagFilter == tag.id,
                      onSelected: (selected) => setState(() => _tagFilter = selected ? tag.id : null),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: events.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Fehler: $error')),
              data: (all) {
                final filtered = _tagFilter == null
                    ? all
                    : [for (final event in all) if (event.tagIds.contains(_tagFilter)) event];
                final occurrences = expandAll(filtered, range.from, range.to);
                return switch (_mode) {
                  CalendarViewMode.month => MonthView(
                      month: _focused,
                      today: now,
                      occurrences: occurrences,
                      tags: tagMap,
                      onTapDay: _openDay,
                      onOpen: (o) => openEventEditor(context, occurrence: o),
                      onDropOnDay: (o, day) => _move(
                        o,
                        o.allDay ? dateOnly(day) : DateTime(day.year, day.month, day.day, o.start.hour, o.start.minute),
                      ),
                    ),
                  CalendarViewMode.week || CalendarViewMode.day => TimeGridView(
                      key: ValueKey('${_mode.name}-${isoDate(range.from)}'),
                      days: [
                        for (var i = 0; i < (_mode == CalendarViewMode.week ? 7 : 1); i++)
                          DateTime(range.from.year, range.from.month, range.from.day + i),
                      ],
                      now: now,
                      occurrences: occurrences,
                      tags: tagMap,
                      onOpen: (o) => openEventEditor(context, occurrence: o),
                      onMove: _move,
                      onCreateAt: (start) => openEventEditor(context, initialStart: start),
                      onTapDay: _openDay,
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}
