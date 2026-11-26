/// Eine Notiz, wie die Oberfläche sie sieht.
class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;

  /// Inhalt in Markdown.
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Titel oder, falls leer, die erste Zeile des Inhalts.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body.trim().split('\n').first.trim();
    return firstLine.isEmpty ? 'Ohne Titel' : firstLine;
  }

  /// Kurzer, einzeiliger Auszug des Inhalts.
  String get preview {
    final singleLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 120 ? singleLine : '${singleLine.substring(0, 120)}…';
  }
}
