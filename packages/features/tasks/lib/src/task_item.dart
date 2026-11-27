/// Eine Aufgabe, wie die Oberfläche sie sieht.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
    this.details,
    this.doneAt,
    this.dueDate,
    this.projectId,
  });

  final String id;
  final String title;
  final String? details;
  final bool done;
  final DateTime? doneAt;

  /// ISO-Datum ohne Uhrzeit, z. B. `2026-11-26`.
  final String? dueDate;
  final DateTime createdAt;

  /// Gesetzt bei Unterpunkten eines Projekts.
  final String? projectId;
}
