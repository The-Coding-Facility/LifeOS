import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../occurrences.dart';
import 'event_chip.dart';

/// Woche oder Tag mit Stundenraster. Termine lassen sich per langem Drücken
/// auf eine andere Uhrzeit oder einen anderen Tag ziehen (15-Minuten-Raster).
class TimeGridView extends StatefulWidget {
  const TimeGridView({
    super.key,
    required this.days,
    required this.now,
    required this.occurrences,
    required this.tags,
    required this.onOpen,
    required this.onMove,
    required this.onCreateAt,
    required this.onTapDay,
  });

  final List<DateTime> days;
  final DateTime now;
  final List<Occurrence> occurrences;
  final Map<String, TagItem> tags;
  final ValueChanged<Occurrence> onOpen;
  final void Function(Occurrence occurrence, DateTime newStart) onMove;
  final ValueChanged<DateTime> onCreateAt;
  final ValueChanged<DateTime> onTapDay;

  static const double hourHeight = 48;
  static const double labelWidth = 44;

  @override
  State<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends State<TimeGridView> {
  final _scroll = ScrollController(initialScrollOffset: 7 * TimeGridView.hourHeight);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allDay = [for (final o in widget.occurrences) if (o.allDay) o];
    final timed = [for (final o in widget.occurrences) if (!o.allDay) o];

    return Column(
      children: [
        // Kopfzeile mit Tagen
        Row(
          children: [
            const SizedBox(width: TimeGridView.labelWidth),
            for (final day in widget.days)
              Expanded(
                child: InkWell(
                  onTap: () => widget.onTapDay(day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(germanWeekdaysShort[day.weekday - 1], style: theme.textTheme.labelSmall),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: isoDate(day) == isoDate(widget.now)
                              ? BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12))
                              : null,
                          child: Text(
                            '${day.day}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isoDate(day) == isoDate(widget.now) ? scheme.onPrimary : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Ganztägige Termine
        if (allDay.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: TimeGridView.labelWidth,
                child: Text('ganzt.', style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
              ),
              for (final day in widget.days)
                Expanded(
                  child: DragTarget<Occurrence>(
                    onAcceptWithDetails: (details) {
                      final o = details.data;
                      widget.onMove(
                        o,
                        o.allDay ? dateOnly(day) : DateTime(day.year, day.month, day.day, o.start.hour, o.start.minute),
                      );
                    },
                    builder: (context, candidates, _) => Container(
                      color: candidates.isEmpty ? null : scheme.primaryContainer,
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final o in allDay)
                            if (o.coversDay(day))
                              DraggableOccurrence(
                                occurrence: o,
                                child: GestureDetector(
                                  onTap: () => widget.onOpen(o),
                                  child: EventChip(occurrence: o, color: occurrenceColor(context, o, widget.tags)),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * TimeGridView.hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: TimeGridView.labelWidth,
                    child: Stack(
                      children: [
                        for (var hour = 1; hour < 24; hour++)
                          Positioned(
                            top: hour * TimeGridView.hourHeight - 7,
                            right: 6,
                            child: Text('${hour.toString().padLeft(2, '0')}:00', style: theme.textTheme.labelSmall),
                          ),
                      ],
                    ),
                  ),
                  for (final day in widget.days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        now: widget.now,
                        occurrences: [for (final o in timed) if (o.coversDay(day)) o],
                        tags: widget.tags,
                        onOpen: widget.onOpen,
                        onMove: widget.onMove,
                        onCreateAt: widget.onCreateAt,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placed {
  _Placed(this.occurrence, this.top, this.height);

  final Occurrence occurrence;
  final double top;
  final double height;
  int lane = 0;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.now,
    required this.occurrences,
    required this.tags,
    required this.onOpen,
    required this.onMove,
    required this.onCreateAt,
  });

  final DateTime day;
  final DateTime now;
  final List<Occurrence> occurrences;
  final Map<String, TagItem> tags;
  final ValueChanged<Occurrence> onOpen;
  final void Function(Occurrence occurrence, DateTime newStart) onMove;
  final ValueChanged<DateTime> onCreateAt;

  static const double _perMinute = TimeGridView.hourHeight / 60;

  /// Minuten seit Mitternacht für eine Position im Raster, auf [snap] gerundet.
  static int _minutesAt(double y, {int snap = 15}) {
    final minutes = (y / _perMinute / snap).round() * snap;
    return minutes.clamp(0, 24 * 60 - snap).toInt();
  }

  List<_Placed> _layout() {
    final dayStart = dateOnly(day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final placed = <_Placed>[];
    for (final o in occurrences) {
      final start = o.start.isBefore(dayStart) ? dayStart : o.start;
      final end = o.end.isAfter(dayEnd) ? dayEnd : o.end;
      final top = start.difference(dayStart).inMinutes * _perMinute;
      final height = math.max(20.0, end.difference(start).inMinutes * _perMinute);
      placed.add(_Placed(o, top, height));
    }
    placed.sort((a, b) => a.top.compareTo(b.top));
    final laneEnds = <double>[];
    for (final item in placed) {
      var lane = laneEnds.indexWhere((end) => end <= item.top + 0.5);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(0);
      }
      laneEnds[lane] = item.top + item.height;
      item.lane = lane;
    }
    return placed;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placed = _layout();
    final lanes = placed.isEmpty ? 1 : placed.map((p) => p.lane).reduce(math.max) + 1;
    final isToday = isoDate(day) == isoDate(now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final laneWidth = width / lanes;
        return DragTarget<Occurrence>(
          onAcceptWithDetails: (details) {
            final box = context.findRenderObject()! as RenderBox;
            final local = box.globalToLocal(details.offset);
            final minutes = _minutesAt(local.dy);
            final o = details.data;
            final target = o.allDay
                ? dateOnly(day)
                : DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
            onMove(o, target);
          },
          builder: (context, candidates, _) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final minutes = _minutesAt(details.localPosition.dy, snap: 30);
              onCreateAt(DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60));
            },
            child: Container(
              decoration: BoxDecoration(
                color: candidates.isEmpty ? null : scheme.primaryContainer.withValues(alpha: 0.4),
                border: Border(left: BorderSide(color: scheme.outlineVariant, width: 0.5)),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var hour = 1; hour < 24; hour++)
                    Positioned(
                      top: hour * TimeGridView.hourHeight,
                      left: 0,
                      right: 0,
                      child: Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
                    ),
                  for (final item in placed)
                    Positioned(
                      top: item.top,
                      left: item.lane * laneWidth + 1,
                      width: laneWidth - 2,
                      height: item.height - 1,
                      child: DraggableOccurrence(
                        occurrence: item.occurrence,
                        feedbackSize: Size(laneWidth - 2, item.height - 1),
                        child: _EventBlock(
                          occurrence: item.occurrence,
                          color: occurrenceColor(context, item.occurrence, tags),
                          onTap: () => onOpen(item.occurrence),
                        ),
                      ),
                    ),
                  if (isToday)
                    Positioned(
                      top: (now.hour * 60 + now.minute) * _perMinute,
                      left: 0,
                      right: 0,
                      child: Container(height: 2, color: scheme.error),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EventBlock extends StatelessWidget {
  const _EventBlock({required this.occurrence, required this.color, required this.onTap});

  final Occurrence occurrence;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = onTagColor(color);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: textColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: occurrence.event.title,
                style: style?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: '\n${formatTime(occurrence.start)}–${formatTime(occurrence.end)}'),
            ],
          ),
          style: style,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
