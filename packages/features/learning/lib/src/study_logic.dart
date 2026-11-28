import 'dart:math';

import 'model.dart';

/// Wie oft eine Frage richtig und falsch beantwortet wurde.
class AnswerTally {
  const AnswerTally({this.right = 0, this.wrong = 0});

  final int right;
  final int wrong;

  AnswerTally add(bool correct) =>
      correct ? AnswerTally(right: right + 1, wrong: wrong) : AnswerTally(right: right, wrong: wrong + 1);
}

/// Richtig/Falsch je Frage (`card:<id>` bzw. `glossary:<id>`) über alle Einheiten.
Map<String, AnswerTally> answerStats(Iterable<StudySession> sessions) {
  final stats = <String, AnswerTally>{};
  for (final session in sessions) {
    for (final answer in session.answers) {
      stats[answer.key] = (stats[answer.key] ?? const AnswerTally()).add(answer.correct);
    }
  }
  return stats;
}

/// Reihenfolge zum Lernen: oft falsch beantwortete und neue Karten zuerst,
/// gleich wichtige gemischt.
List<Flashcard> learningOrder(List<Flashcard> cards, Map<String, AnswerTally> stats, Random random) {
  double priority(Flashcard card) {
    final tally = stats['${AnswerSource.card.key}:${card.id}'];
    if (tally == null) return 1; // neu
    return (tally.wrong * 2 - tally.right).toDouble();
  }

  final shuffled = [...cards]..shuffle(random);
  final keyed = [for (var i = 0; i < shuffled.length; i++) (card: shuffled[i], index: i)];
  keyed.sort((a, b) {
    final byPriority = priority(b.card).compareTo(priority(a.card));
    return byPriority != 0 ? byPriority : a.index.compareTo(b.index);
  });
  return [for (final entry in keyed) entry.card];
}

/// Eine Prüfungsfrage.
class ExamQuestion {
  const ExamQuestion({
    required this.source,
    required this.itemId,
    required this.prompt,
    required this.answerText,
    this.options,
    this.correctOptions = const {},
  });

  final AnswerSource source;
  final String itemId;
  final String prompt;

  /// Richtige Antwort als Text (für die Ergebnisübersicht).
  final String answerText;

  /// Auswahlmöglichkeiten; `null` = Selbstbewertung nach „Lösen“.
  final List<String>? options;

  /// Indizes der richtigen Möglichkeiten.
  final Set<int> correctOptions;

  bool get selfGraded => options == null;

  /// Ist die Auswahl [selected] genau richtig?
  bool isCorrectSelection(Set<int> selected) =>
      selected.length == correctOptions.length && selected.containsAll(correctOptions);
}

/// Frage zu einer Karte.
ExamQuestion questionForCard(Flashcard card) {
  if (card.kind == CardKind.choice && card.choices.isNotEmpty) {
    return ExamQuestion(
      source: AnswerSource.card,
      itemId: card.id,
      prompt: card.question,
      answerText: card.correctAnswerText,
      options: [for (final choice in card.choices) choice.text],
      correctOptions: {
        for (var i = 0; i < card.choices.length; i++)
          if (card.choices[i].correct) i,
      },
    );
  }
  return ExamQuestion(source: AnswerSource.card, itemId: card.id, prompt: card.question, answerText: card.answer);
}

/// Frage zu einem Glossar-Begriff: Begriff mit bis zu vier Erklärungen zur
/// Auswahl. Gibt es keine andere Erklärung, bewertet man sich selbst.
ExamQuestion questionForGlossary(GlossaryEntry entry, List<GlossaryEntry> all, Random random) {
  final others = <String>{
    for (final other in all)
      if (other.id != entry.id && other.explanation.trim().isNotEmpty && other.explanation != entry.explanation)
        other.explanation,
  }.toList()
    ..shuffle(random);
  final prompt = 'Was bedeutet „${entry.term}“?';
  if (others.isEmpty || entry.explanation.trim().isEmpty) {
    return ExamQuestion(source: AnswerSource.glossary, itemId: entry.id, prompt: prompt, answerText: entry.explanation);
  }
  final options = [entry.explanation, ...others.take(3)]..shuffle(random);
  return ExamQuestion(
    source: AnswerSource.glossary,
    itemId: entry.id,
    prompt: prompt,
    answerText: entry.explanation,
    options: options,
    correctOptions: {options.indexOf(entry.explanation)},
  );
}

/// Stellt eine Prüfung mit höchstens [count] Fragen aus den gewählten Quellen
/// zusammen, zufällig gemischt.
List<ExamQuestion> buildExam({
  required List<Flashcard> cards,
  required List<GlossaryEntry> glossary,
  required bool includeCards,
  required bool includeGlossary,
  required int count,
  required Random random,
}) {
  final pool = <ExamQuestion>[
    if (includeCards)
      for (final card in cards) questionForCard(card),
    if (includeGlossary)
      for (final entry in glossary) questionForGlossary(entry, glossary, random),
  ]..shuffle(random);
  return pool.take(count < 0 ? 0 : count).toList();
}

/// Ergebnis einer Prüfung.
class ExamResult {
  const ExamResult({required this.total, required this.correct, required this.passPercent, required this.answers});

  final int total;
  final int correct;
  final int passPercent;
  final List<StudyAnswer> answers;

  double get rate => total == 0 ? 0 : correct / total;
  bool get passed => rate * 100 >= passPercent;
}

/// Wertet aus. [answers]: Index der Frage → richtig. Unbeantwortete zählen
/// als falsch.
ExamResult scoreExam(List<ExamQuestion> questions, Map<int, bool> answers, int passPercent) {
  final list = <StudyAnswer>[
    for (var i = 0; i < questions.length; i++)
      StudyAnswer(source: questions[i].source, itemId: questions[i].itemId, correct: answers[i] ?? false),
  ];
  return ExamResult(
    total: questions.length,
    correct: list.where((answer) => answer.correct).length,
    passPercent: passPercent,
    answers: list,
  );
}

/// Restzeit einer Prüfung nach der Wanduhr (läuft auch im Hintergrund
/// weiter). `null` ohne Zeitlimit; nie negativ.
Duration? remainingTime({required DateTime startedAt, required Duration? limit, required DateTime now}) {
  if (limit == null || limit == Duration.zero) return null;
  final left = limit - now.difference(startedAt);
  return left.isNegative ? Duration.zero : left;
}

/// Veränderung der Trefferquote: Durchschnitt der letzten [window] Einheiten
/// gegen die [window] davor, in Prozentpunkten. `null` bei zu wenig Daten.
int? studyTrend(List<StudySession> sessions, {int window = 5}) {
  final sorted = [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (sorted.length < 2) return null;
  final recent = sorted.take(window).toList();
  final before = sorted.skip(recent.length).take(window).toList();
  if (before.isEmpty) return null;
  double average(List<StudySession> list) => list.map((s) => s.rate).reduce((a, b) => a + b) / list.length;
  return ((average(recent) - average(before)) * 100).round();
}

/// Die am häufigsten falsch beantworteten Fragen, häufigste zuerst.
List<({String key, int wrong})> mostMissed(Iterable<StudySession> sessions, {int limit = 5}) {
  final entries = [
    for (final MapEntry(:key, :value) in answerStats(sessions).entries)
      if (value.wrong > 0) (key: key, wrong: value.wrong),
  ]..sort((a, b) => b.wrong.compareTo(a.wrong));
  return entries.take(limit).toList();
}

/// Anzahl Einheiten und Gesamtquote eines Bereichs (`rate` ist `null`
/// ohne beantwortete Fragen).
({int count, double? rate}) areaSummary(Iterable<StudySession> sessions, String areaId) {
  var count = 0;
  var total = 0;
  var correct = 0;
  for (final session in sessions) {
    if (session.areaId != areaId) continue;
    count++;
    total += session.total;
    correct += session.correct;
  }
  return (count: count, rate: total == 0 ? null : correct / total);
}
