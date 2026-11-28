import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model.dart';

/// Lernbereiche, Glossar, Karten, Ressourcen und Lerneinheiten.
class LearningRepository {
  LearningRepository(this._db, ChangeRecorder recorder) : _writer = RecordWriter(_db, recorder);

  final LifeosDatabase _db;
  final RecordWriter _writer;
  static const _access = LearningDatabaseAccess();

  static const _areaGroups = {
    'name': ['name'],
    'description': ['description'],
    'color': ['color_index'],
    'project': ['project_id'],
  };
  static const _glossaryGroups = {
    'area': ['area_id'],
    'term': ['term'],
    'explanation': ['explanation'],
  };
  static const _cardGroups = {
    'area': ['area_id'],
    'question': ['question'],
    'answer': ['answer', 'kind', 'choices'],
  };
  static const _resourceGroups = {
    'area': ['area_id'],
    'title': ['title'],
    'link': ['link'],
    'note': ['note'],
  };

  // ------------------------------------------------------------ Bereiche

  Stream<List<LearningArea>> watchAreas() {
    final query = _db.select(_db.learningAreas)..where((a) => a.deletedHlc.isNull());
    return query.watch().map((rows) {
      final areas = [for (final row in rows) _access.area(row)];
      areas.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return areas;
    });
  }

  Future<String> createArea({required String name, String description = '', int colorIndex = 0, String? projectId}) {
    final columns = {
      'name': _require(name, 'Ein Lernbereich braucht einen Namen.'),
      'description': description.trim(),
      'color_index': colorIndex,
      'project_id': projectId,
    };
    return _create('learning_areas', _db.learningAreas, _areaGroups, columns);
  }

  Future<void> updateArea(String id, {required String name, String description = '', int colorIndex = 0, String? projectId}) async {
    final row = await (_db.select(_db.learningAreas)..where((a) => a.id.equals(id) & a.deletedHlc.isNull())).getSingleOrNull();
    if (row == null) return;
    await _change('learning_areas', _db.learningAreas, id, _areaGroups, {
      'name': _require(name, 'Ein Lernbereich braucht einen Namen.'),
      'description': description.trim(),
      'color_index': colorIndex,
      'project_id': projectId,
    }, {
      'name': row.name,
      'description': row.description,
      'color_index': row.colorIndex,
      'project_id': row.projectId,
    });
  }

  Future<void> deleteArea(String id) => _db.transaction(() => _writer.delete('learning_areas', _db.learningAreas, id));

  // ------------------------------------------------------------- Glossar

  Stream<List<GlossaryEntry>> watchGlossary(String areaId) {
    final query = _db.select(_db.glossaryEntries)..where((g) => g.deletedHlc.isNull() & g.areaId.equals(areaId));
    return query.watch().map((rows) {
      final entries = [for (final row in rows) _access.glossary(row)];
      entries.sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
      return entries;
    });
  }

  Future<String> addGlossary(String areaId, {required String term, String explanation = ''}) => _create(
        'glossary_entries',
        _db.glossaryEntries,
        _glossaryGroups,
        {'area_id': areaId, 'term': _require(term, 'Ein Begriff braucht einen Namen.'), 'explanation': explanation.trim()},
      );

  Future<void> updateGlossary(GlossaryEntry entry, {required String term, required String explanation}) => _change(
        'glossary_entries',
        _db.glossaryEntries,
        entry.id,
        _glossaryGroups,
        {'area_id': entry.areaId, 'term': _require(term, 'Ein Begriff braucht einen Namen.'), 'explanation': explanation.trim()},
        {'area_id': entry.areaId, 'term': entry.term, 'explanation': entry.explanation},
      );

  Future<void> deleteGlossary(String id) =>
      _db.transaction(() => _writer.delete('glossary_entries', _db.glossaryEntries, id));

  // --------------------------------------------------------------- Karten

  Stream<List<Flashcard>> watchCards(String areaId) {
    final query = _db.select(_db.flashcards)
      ..where((c) => c.deletedHlc.isNull() & c.areaId.equals(areaId))
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _access.card(row)]);
  }

  Future<String> addCard(
    String areaId, {
    required String question,
    CardKind kind = CardKind.text,
    String answer = '',
    List<Choice> choices = const [],
  }) =>
      _create('flashcards', _db.flashcards, _cardGroups, _cardColumns(areaId, question, kind, answer, choices));

  Future<void> updateCard(
    Flashcard card, {
    required String question,
    required CardKind kind,
    String answer = '',
    List<Choice> choices = const [],
  }) =>
      _change(
        'flashcards',
        _db.flashcards,
        card.id,
        _cardGroups,
        _cardColumns(card.areaId, question, kind, answer, choices),
        _cardColumns(card.areaId, card.question, card.kind, card.answer, card.choices),
      );

  Future<void> deleteCard(String id) => _db.transaction(() => _writer.delete('flashcards', _db.flashcards, id));

  // ----------------------------------------------------------- Ressourcen

  Stream<List<LearningResource>> watchResources(String areaId) {
    final query = _db.select(_db.learningResources)
      ..where((r) => r.deletedHlc.isNull() & r.areaId.equals(areaId))
      ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _access.resource(row)]);
  }

  Future<String> addResource(String areaId, {required String title, String link = '', String note = ''}) => _create(
        'learning_resources',
        _db.learningResources,
        _resourceGroups,
        {'area_id': areaId, 'title': _require(title, 'Eine Ressource braucht einen Titel.'), 'link': link.trim(), 'note': note.trim()},
      );

  Future<void> updateResource(LearningResource resource, {required String title, String link = '', String note = ''}) =>
      _change(
        'learning_resources',
        _db.learningResources,
        resource.id,
        _resourceGroups,
        {
          'area_id': resource.areaId,
          'title': _require(title, 'Eine Ressource braucht einen Titel.'),
          'link': link.trim(),
          'note': note.trim(),
        },
        {'area_id': resource.areaId, 'title': resource.title, 'link': resource.link, 'note': resource.note},
      );

  Future<void> deleteResource(String id) =>
      _db.transaction(() => _writer.delete('learning_resources', _db.learningResources, id));

  // -------------------------------------------------------- Lerneinheiten

  /// Alle Lerneinheiten, neueste zuerst (für Statistik und Projekte).
  Stream<List<StudySession>> watchSessions() {
    final query = _db.select(_db.studySessions)
      ..where((s) => s.deletedHlc.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    return query.watch().map((rows) => [for (final row in rows) _access.session(row)]);
  }

  Future<String> saveSession({
    required String areaId,
    required StudyMode mode,
    required DateTime startedAt,
    required Duration duration,
    required List<StudyAnswer> answers,
    int? passPercent,
  }) =>
      _create('study_sessions', _db.studySessions, const {
        'data': [
          'area_id',
          'mode',
          'started_at',
          'duration_seconds',
          'total',
          'correct',
          'pass_percent',
          'answers',
        ],
      }, {
        'area_id': areaId,
        'mode': mode.key,
        'started_at': startedAt.toUtc().millisecondsSinceEpoch,
        'duration_seconds': duration.inSeconds,
        'total': answers.length,
        'correct': answers.where((a) => a.correct).length,
        'pass_percent': passPercent,
        'answers': jsonEncode([for (final answer in answers) answer.toJson()]),
      });

  // ---------------------------------------------------------------- Intern

  Future<String> _create(
    String entity,
    TableInfo<Table, Object?> table,
    Map<String, List<String>> groups,
    Map<String, Object?> columns,
  ) {
    return _db.transaction(() async {
      final id = Ids.newId();
      await _writer.insert(entity, table, id, RecordWriter.allGroups(groups, columns));
      return id;
    });
  }

  Future<void> _change(
    String entity,
    TableInfo<Table, Object?> table,
    String id,
    Map<String, List<String>> groups,
    Map<String, Object?> wanted,
    Map<String, Object?> existing,
  ) {
    return _db.transaction(
      () => _writer.update(entity, table, id, RecordWriter.changedGroups(groups, wanted, existing)),
    );
  }

  static Map<String, Object?> _cardColumns(
    String areaId,
    String question,
    CardKind kind,
    String answer,
    List<Choice> choices,
  ) =>
      {
        'area_id': areaId,
        'question': _require(question, 'Eine Karte braucht eine Frage.'),
        'answer': kind == CardKind.text ? answer.trim() : '',
        'kind': kind.key,
        'choices': jsonEncode(kind == CardKind.choice ? [for (final c in choices) c.toJson()] : const []),
      };

  static String _require(String text, String message) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError(message);
    return trimmed;
  }
}

/// Wandelt Zeilen in Modelle.
class LearningDatabaseAccess {
  const LearningDatabaseAccess();

  LearningArea area(LearningAreaRow row) => LearningArea(
        id: row.id,
        name: row.name,
        description: row.description,
        colorIndex: row.colorIndex,
        projectId: row.projectId,
      );

  GlossaryEntry glossary(GlossaryEntryRow row) =>
      GlossaryEntry(id: row.id, areaId: row.areaId, term: row.term, explanation: row.explanation);

  Flashcard card(FlashcardRow row) => Flashcard(
        id: row.id,
        areaId: row.areaId,
        question: row.question,
        answer: row.answer,
        kind: CardKind.fromKey(row.kind),
        choices: [
          for (final item in _decodeList(row.choices))
            if (Choice.fromJson(item) case final choice?) choice,
        ],
      );

  LearningResource resource(LearningResourceRow row) =>
      LearningResource(id: row.id, areaId: row.areaId, title: row.title, link: row.link, note: row.note);

  StudySession session(StudySessionRow row) => StudySession(
        id: row.id,
        areaId: row.areaId,
        mode: StudyMode.fromKey(row.mode),
        startedAt: DateTime.fromMillisecondsSinceEpoch(row.startedAt, isUtc: true).toLocal(),
        duration: Duration(seconds: row.durationSeconds),
        total: row.total,
        correct: row.correct,
        passPercent: row.passPercent,
        answers: [
          for (final item in _decodeList(row.answers))
            if (StudyAnswer.fromJson(item) case final answer?) answer,
        ],
      );

  static List<Object?> _decodeList(String json) {
    try {
      final value = jsonDecode(json);
      return value is List ? value : const [];
    } on FormatException {
      return const [];
    }
  }
}
