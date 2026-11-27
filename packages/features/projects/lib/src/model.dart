import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

/// Status eines Projekts.
enum ProjectStatus {
  active('active', 'Aktiv'),
  done('done', 'Abgeschlossen');

  const ProjectStatus(this.key, this.label);

  final String key;
  final String label;

  static ProjectStatus fromKey(String key) =>
      values.firstWhere((status) => status.key == key, orElse: () => ProjectStatus.active);
}

/// Ein Projekt.
class Project {
  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.deadline,
    this.colorIndex = 0,
    this.status = ProjectStatus.active,
  });

  final String id;
  final String name;
  final String description;

  /// Deadline (lokale Mitternacht) oder `null`.
  final DateTime? deadline;
  final int colorIndex;
  final ProjectStatus status;

  bool get isActive => status == ProjectStatus.active;
}

/// Formularwerte eines Projekts.
class ProjectDraft {
  const ProjectDraft({required this.name, this.description = '', this.deadline, this.colorIndex = 0});

  final String name;
  final String description;
  final DateTime? deadline;
  final int colorIndex;
}

/// Anteil erledigter Unterpunkte, 0 bis 1. Ohne Unterpunkte 0.
double progressOf(List<TaskItem> subtasks) {
  if (subtasks.isEmpty) return 0;
  return subtasks.where((task) => task.done).length / subtasks.length;
}

/// „Noch 12 Tage“, „Heute fällig“, „Seit 2 Tagen überfällig“ oder `null`.
String? deadlineText(DateTime? deadline, DateTime today) {
  if (deadline == null) return null;
  final days = DateTime.utc(deadline.year, deadline.month, deadline.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (days == 0) return 'Heute fällig';
  if (days == 1) return 'Noch 1 Tag';
  if (days > 1) return 'Noch $days Tage';
  if (days == -1) return 'Seit 1 Tag überfällig';
  return 'Seit ${-days} Tagen überfällig';
}

/// Deadline als Text für Listen, z. B. „bis 31.12.2026 · Noch 34 Tage“.
String describeDeadline(DateTime deadline, DateTime today) {
  final day = deadline.day.toString().padLeft(2, '0');
  final month = deadline.month.toString().padLeft(2, '0');
  return 'bis $day.$month.${deadline.year} · ${deadlineText(deadline, dateOnly(today))}';
}
