/// Ein Lernbereich.
class LearningArea {
  const LearningArea({
    required this.id,
    required this.name,
    this.description = '',
    this.colorIndex = 0,
    this.projectId,
  });

  final String id;
  final String name;
  final String description;
  final int colorIndex;
  final String? projectId;
}

/// Ein Begriff im Glossar.
class GlossaryEntry {
  const GlossaryEntry({required this.id, required this.areaId, required this.term, this.explanation = ''});

  final String id;
  final String areaId;
  final String term;
  final String explanation;
}

/// Art einer Karteikarte.
enum CardKind {
  text('text', 'Text'),
  choice('choice', 'Multiple Choice');

  const CardKind(this.key, this.label);

  final String key;
  final String label;

  static CardKind fromKey(String key) => key == 'choice' ? CardKind.choice : CardKind.text;
}

/// Eine Antwortmöglichkeit bei Multiple Choice.
class Choice {
  const Choice({required this.text, this.correct = false});

  final String text;
  final bool correct;

  Map<String, Object?> toJson() => {'text': text, 'correct': correct};

  static Choice? fromJson(Object? json) {
    if (json is! Map || json['text'] is! String) return null;
    return Choice(text: json['text'] as String, correct: json['correct'] == true);
  }
}

/// Eine Karteikarte.
class Flashcard {
  const Flashcard({
    required this.id,
    required this.areaId,
    required this.question,
    this.answer = '',
    this.kind = CardKind.text,
    this.choices = const [],
  });

  final String id;
  final String areaId;
  final String question;

  /// Antwort bei Text-Karten.
  final String answer;
  final CardKind kind;

  /// Antwortmöglichkeiten bei Multiple Choice.
  final List<Choice> choices;

  /// Richtige Antwort als Text, für Ergebnisübersichten.
  String get correctAnswerText => kind == CardKind.choice
      ? choices.where((c) => c.correct).map((c) => c.text).join(', ')
      : answer;
}

/// Eine Ressource (Buch, Link, Kurs …).
class LearningResource {
  const LearningResource({required this.id, required this.areaId, required this.title, this.link = '', this.note = ''});

  final String id;
  final String areaId;
  final String title;
  final String link;
  final String note;
}

/// Woher eine Frage stammt.
enum AnswerSource {
  card('card'),
  glossary('glossary');

  const AnswerSource(this.key);

  final String key;

  static AnswerSource fromKey(String? key) => key == 'glossary' ? AnswerSource.glossary : AnswerSource.card;
}

/// Eine beantwortete Frage.
class StudyAnswer {
  const StudyAnswer({required this.source, required this.itemId, required this.correct});

  final AnswerSource source;
  final String itemId;
  final bool correct;

  String get key => '${source.key}:$itemId';

  Map<String, Object?> toJson() => {'kind': source.key, 'id': itemId, 'correct': correct};

  static StudyAnswer? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return StudyAnswer(
      source: AnswerSource.fromKey(json['kind'] as String?),
      itemId: json['id'] as String,
      correct: json['correct'] == true,
    );
  }
}

/// Lernen oder Prüfung.
enum StudyMode {
  learn('learn', 'Lernen'),
  exam('exam', 'Prüfung');

  const StudyMode(this.key, this.label);

  final String key;
  final String label;

  static StudyMode fromKey(String key) => key == 'exam' ? StudyMode.exam : StudyMode.learn;
}

/// Eine abgeschlossene Lerneinheit oder Prüfung.
class StudySession {
  const StudySession({
    required this.id,
    required this.areaId,
    required this.mode,
    required this.startedAt,
    required this.duration,
    required this.total,
    required this.correct,
    this.passPercent,
    this.answers = const [],
  });

  final String id;
  final String areaId;
  final StudyMode mode;
  final DateTime startedAt;
  final Duration duration;
  final int total;
  final int correct;

  /// Bestehensgrenze in Prozent (nur Prüfungen).
  final int? passPercent;
  final List<StudyAnswer> answers;

  /// Anteil richtiger Antworten, 0 bis 1.
  double get rate => total == 0 ? 0 : correct / total;

  /// Bestanden? `null` bei Lerneinheiten.
  bool? get passed => passPercent == null ? null : rate * 100 >= passPercent!;
}
