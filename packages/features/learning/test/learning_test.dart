import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_learning/lifeos_learning.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

Flashcard card(String id, {CardKind kind = CardKind.text, List<Choice> choices = const []}) =>
    Flashcard(id: id, areaId: 'a', question: 'Frage $id', answer: 'Antwort $id', kind: kind, choices: choices);

StudySession session(DateTime when, int correct, int total, {List<StudyAnswer> answers = const [], int? pass}) =>
    StudySession(
      id: '${when.millisecondsSinceEpoch}',
      areaId: 'a',
      mode: pass == null ? StudyMode.learn : StudyMode.exam,
      startedAt: when,
      duration: const Duration(minutes: 5),
      total: total,
      correct: correct,
      passPercent: pass,
      answers: answers,
    );

StudyAnswer answer(String id, bool correct) =>
    StudyAnswer(source: AnswerSource.card, itemId: id, correct: correct);

void main() {
  group('Lernreihenfolge', () {
    test('oft falsch beantwortete und neue Karten zuerst', () {
      final stats = answerStats([
        session(DateTime(2026, 11, 1), 1, 3, answers: [answer('gut', true), answer('schwer', false), answer('schwer', false)]),
      ]);
      final order = learningOrder([card('gut'), card('neu'), card('schwer')], stats, Random(1));
      expect([for (final c in order) c.id], ['schwer', 'neu', 'gut']);
    });
  });

  group('Prüfung', () {
    const glossary = [
      GlossaryEntry(id: 'g1', areaId: 'a', term: 'Hund', explanation: 'perro'),
      GlossaryEntry(id: 'g2', areaId: 'a', term: 'Katze', explanation: 'gato'),
      GlossaryEntry(id: 'g3', areaId: 'a', term: 'Haus', explanation: 'casa'),
      GlossaryEntry(id: 'g4', areaId: 'a', term: 'Baum', explanation: 'árbol'),
      GlossaryEntry(id: 'g5', areaId: 'a', term: 'Auto', explanation: 'coche'),
    ];

    test('Glossar-Frage mit vier verschiedenen Erklärungen, eine richtig', () {
      final question = questionForGlossary(glossary.first, glossary, Random(3));
      expect(question.options, hasLength(4));
      expect(question.options!.toSet(), hasLength(4));
      expect(question.options![question.correctOptions.single], 'perro');
      expect(question.isCorrectSelection({question.correctOptions.single}), isTrue);
    });

    test('Glossar mit einem Eintrag: Selbstbewertung', () {
      final question = questionForGlossary(glossary.first, [glossary.first], Random(3));
      expect(question.selfGraded, isTrue);
      expect(question.answerText, 'perro');
    });

    test('Multiple Choice mit zwei richtigen braucht beide', () {
      final question = questionForCard(card('mc', kind: CardKind.choice, choices: const [
        Choice(text: 'A', correct: true),
        Choice(text: 'B'),
        Choice(text: 'C', correct: true),
      ]));
      expect(question.isCorrectSelection({0}), isFalse);
      expect(question.isCorrectSelection({0, 2}), isTrue);
      expect(question.isCorrectSelection({0, 1, 2}), isFalse);
    });

    test('Fragen aus den gewählten Quellen, höchstens die Anzahl', () {
      final cards = [card('k1'), card('k2'), card('k3')];
      final onlyCards = buildExam(cards: cards, glossary: glossary, includeCards: true, includeGlossary: false, count: 10, random: Random(2));
      expect(onlyCards, hasLength(3));
      expect(onlyCards.every((q) => q.source == AnswerSource.card), isTrue);
      final mixed = buildExam(cards: cards, glossary: glossary, includeCards: true, includeGlossary: true, count: 4, random: Random(2));
      expect(mixed, hasLength(4));
    });

    test('Auswertung: Unbeantwortetes ist falsch, Bestehensgrenze', () {
      final questions = [for (final c in [card('1'), card('2'), card('3'), card('4')]) questionForCard(c)];
      final result = scoreExam(questions, {0: true, 1: true, 2: false}, 60);
      expect(result.correct, 2);
      expect(result.total, 4);
      expect(result.passed, isFalse);
      expect(result.answers[3].correct, isFalse);
      expect(scoreExam(questions, {0: true, 1: true, 2: true}, 60).passed, isTrue);
    });

    test('Restzeit nach Wanduhr, nie negativ', () {
      final start = DateTime(2026, 11, 28, 10);
      expect(remainingTime(startedAt: start, limit: const Duration(minutes: 10), now: DateTime(2026, 11, 28, 10, 4)),
          const Duration(minutes: 6));
      expect(remainingTime(startedAt: start, limit: const Duration(minutes: 10), now: DateTime(2026, 11, 28, 11)),
          Duration.zero);
      expect(remainingTime(startedAt: start, limit: null, now: start), isNull);
    });
  });

  group('Statistik', () {
    test('Trend der letzten fünf gegen die fünf davor', () {
      final sessions = [
        for (var i = 0; i < 5; i++) session(DateTime(2026, 11, 1 + i), 5, 10),
        for (var i = 0; i < 5; i++) session(DateTime(2026, 11, 10 + i), 8, 10),
      ];
      expect(studyTrend(sessions), 30);
      expect(studyTrend([session(DateTime(2026, 11, 1), 5, 10)]), isNull);
    });

    test('am häufigsten falsch', () {
      final missed = mostMissed([
        session(DateTime(2026, 11, 1), 0, 3, answers: [answer('x', false), answer('y', false), answer('x', false)]),
      ]);
      expect(missed.first.key, 'card:x');
      expect(missed.first.wrong, 2);
    });

    test('Zusammenfassung eines Bereichs für Projekte', () {
      final summary = areaSummary([session(DateTime(2026, 11, 1), 3, 4), session(DateTime(2026, 11, 2), 3, 6)], 'a');
      expect(summary.count, 2);
      expect(summary.rate, 0.6);
      expect(areaSummary(const [], 'a').rate, isNull);
    });
  });

  group('Speichern', () {
    late LifeosDatabase db;
    late LearningRepository repository;

    setUp(() async {
      db = LifeosDatabase(NativeDatabase.memory());
      repository = LearningRepository(db, await ChangeRecorder.open(db));
    });

    tearDown(() => db.close());

    test('Bereich mit Glossar, Karten, Ressourcen und Einheit', () async {
      final area = await repository.createArea(name: 'Spanisch', projectId: 'reise');
      await repository.addGlossary(area, term: 'Hund', explanation: 'perro');
      final cardId = await repository.addCard(
        area,
        question: 'Hauptstadt?',
        kind: CardKind.choice,
        choices: const [Choice(text: 'Madrid', correct: true), Choice(text: 'Lissabon')],
      );
      await repository.addResource(area, title: 'Duolingo', link: 'https://example.org');
      await repository.saveSession(
        areaId: area,
        mode: StudyMode.exam,
        startedAt: DateTime(2026, 11, 28, 10),
        duration: const Duration(minutes: 3),
        answers: [StudyAnswer(source: AnswerSource.card, itemId: cardId, correct: true)],
        passPercent: 60,
      );

      expect((await repository.watchAreas().first).single.projectId, 'reise');
      expect((await repository.watchGlossary(area).first).single.explanation, 'perro');
      final cards = await repository.watchCards(area).first;
      expect(cards.single.kind, CardKind.choice);
      expect(cards.single.correctAnswerText, 'Madrid');
      expect((await repository.watchResources(area).first).single.link, 'https://example.org');
      final sessions = await repository.watchSessions().first;
      expect(sessions.single.passed, isTrue);
      expect(sessions.single.answers.single.itemId, cardId);

      await repository.updateCard(cards.single, question: 'Hauptstadt Spaniens?', kind: CardKind.text, answer: 'Madrid');
      final updated = (await repository.watchCards(area).first).single;
      expect(updated.kind, CardKind.text);
      expect(updated.choices, isEmpty);
      await repository.deleteArea(area);
      expect(await repository.watchAreas().first, isEmpty);
    });
  });
}
