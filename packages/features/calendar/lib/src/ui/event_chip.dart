import 'package:flutter/material.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../occurrences.dart';

/// Farbe eines Vorkommens: die des ersten bekannten Tags, sonst Primärfarbe.
Color occurrenceColor(BuildContext context, Occurrence occurrence, Map<String, TagItem> tags) {
  for (final id in occurrence.event.tagIds) {
    final tag = tags[id];
    if (tag != null) return tagColor(tag.colorIndex);
  }
  return Theme.of(context).colorScheme.primary;
}

/// Kompakte Zeile für einen Termin in der Monatsansicht und ganztägigen Zeile.
class EventChip extends StatelessWidget {
  const EventChip({super.key, required this.occurrence, required this.color, this.showTime = true});

  final Occurrence occurrence;
  final Color color;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final text = occurrence.allDay || !showTime
        ? occurrence.event.title
        : '${formatTime(occurrence.start)} ${occurrence.event.title}';
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onTagColor(color)),
      ),
    );
  }
}

/// Macht [child] per langem Drücken verschiebbar.
class DraggableOccurrence extends StatelessWidget {
  const DraggableOccurrence({
    super.key,
    required this.occurrence,
    required this.child,
    this.feedbackSize,
  });

  final Occurrence occurrence;
  final Widget child;
  final Size? feedbackSize;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Occurrence>(
      data: occurrence,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: feedbackSize?.width ?? 140,
            height: feedbackSize?.height,
            child: child,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: child,
    );
  }
}
