import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../learning_repository.dart';
import '../model.dart';
import '../providers.dart';
import '../study_logic.dart';

/// Einstellungen einer Prüfung.
class ExamSetup {
  const ExamSetup({
    required this.includeCards,
    required this.includeGlossary,
    required this.count,
    required this.minutes,
    required this.passPercent,
  });

  final bool includeCards;
  final bool includeGlossary;
  final int count;

  /// 0 = ohne Zeitlimit.
  final int minutes;
  final int passPercent;
}

/// Fragt Quelle, Anzahl, Zeit und Bestehensgrenze ab.
Future<ExamSetup?> showExamSetup(BuildContext context, {required int cardCount, required int glossaryCount}) {
  return showDialog<ExamSetup>(
    context: context,
    builder: (context) => _ExamSetupDialog(cardCount: cardCount, glossaryCount: glossaryCount),
  );
}

class _ExamSetupDialog extends StatefulWidget {
  const _ExamSetupDialog({required this.cardCount, required this.glossaryCount});

  final int cardCount;
  final int glossaryCount;

  @override
  State<_ExamSetupDialog> createState() => _ExamSetupDialogState();
}

class _ExamSetupDialogState extends State<_ExamSetupDialog> {
  late var _cards = widget.cardCount > 0;
  late var _glossary = widget.glossaryCount > 0 && widget.cardCount == 0;
  var _count = 10;
  var _minutes = 10;
  var _pass = 60;

  int get _available => (_cards ? widget.cardCount : 0) + (_glossary ? widget.glossaryCount : 0);

  Widget _stepper(String label, int value, int lowest, int highest, int step, ValueChanged<int> onChanged,
      {String suffix = ''}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > lowest ? () => onChanged(max(lowest, value - step)) : null,
        ),
        SizedBox(
          width: 64,
          child: Text(value == 0 && suffix == ' Min' ? 'ohne' : '$value$suffix', textAlign: TextAlign.center),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < highest ? () => onChanged(min(highest, value + step)) : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = min(_count, _available);
    return AlertDialog(
      title: const Text('Prüfung einstellen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Karten (${widget.cardCount})'),
              value: _cards,
              onChanged: widget.cardCount == 0 ? null : (value) => setState(() => _cards = value ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Glossar-Bedeutungen (${widget.glossaryCount})'),
              value: _glossary,
              onChanged: widget.glossaryCount == 0 ? null : (value) => setState(() => _glossary = value ?? false),
            ),
            _stepper('Fragen', count, 1, max(1, _available), 1, (v) => setState(() => _count = v)),
            _stepper('Zeit', _minutes, 0, 180, 5, (v) => setState(() => _minutes = v), suffix: ' Min'),
            _stepper('Bestehen ab', _pass, 10, 100, 5, (v) => setState(() => _pass = v), suffix: ' %'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _available == 0
              ? null
              : () => Navigator.of(context).pop(
                    ExamSetup(
                      includeCards: _cards,
                      includeGlossary: _glossary,
                      count: count,
                      minutes: _minutes,
                      passPercent: _pass,
                    ),
                  ),
          child: const Text('Starten'),
        ),
      ],
    );
  }
}

/// Zeigt eine Frage: Auswahl (automatisch bewertet) oder „Lösen“ mit
/// Selbstbewertung. Meldet das Ergebnis über [onAnswered].
class QuestionView extends StatefulWidget {
  const QuestionView({super.key, required this.question, required this.onAnswered});

  final ExamQuestion question;
  final ValueChanged<bool> onAnswered;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _selected = <int>{};
  var _revealed = false;
  bool? _autoResult;

  @override
  void didUpdateWidget(QuestionView old) {
    super.didUpdateWidget(old);
    if (old.question != widget.question) {
      _selected.clear();
      _revealed = false;
      _autoResult = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question;
    final options = question.options;
    final multi = question.correctOptions.length > 1;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(question.prompt, style: theme.textTheme.headlineSmall),
        if (multi && !_revealed) Text('Mehrere Antworten richtig', style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        if (options != null)
          for (var i = 0; i < options.length; i++)
            Card(
              color: !_revealed
                  ? (_selected.contains(i) ? theme.colorScheme.primaryContainer : null)
                  : question.correctOptions.contains(i)
                      ? const Color(0xFF2E9E6B).withValues(alpha: 0.25)
                      : (_selected.contains(i) ? theme.colorScheme.errorContainer : null),
              child: ListTile(
                title: Text(options[i]),
                leading: Icon(_selected.contains(i) ? Icons.check_box : Icons.check_box_outline_blank),
                onTap: _revealed
                    ? null
                    : () => setState(() => _selected.contains(i) ? _selected.remove(i) : _selected.add(i)),
              ),
            )
        else if (_revealed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(question.answerText.isEmpty ? '(keine Antwort hinterlegt)' : question.answerText,
                  style: theme.textTheme.titleMedium),
            ),
          ),
        const SizedBox(height: 24),
        if (!_revealed)
          FilledButton(
            onPressed: options != null && _selected.isEmpty ? null : () => setState(() {
              _revealed = true;
              if (options != null) _autoResult = question.isCorrectSelection(_selected);
            }),
            child: Text(options == null ? 'Lösen' : 'Prüfen'),
          )
        else if (_autoResult != null) ...[
          Text(
            _autoResult! ? 'Richtig!' : 'Leider falsch. Richtig: ${question.answerText}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _autoResult! ? const Color(0xFF2E9E6B) : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => widget.onAnswered(_autoResult!), child: const Text('Weiter')),
        ] else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onAnswered(false),
                  icon: const Icon(Icons.close),
                  label: const Text('Falsch'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onAnswered(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Richtig'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Lernmodus: alle Karten der Reihe nach.
class LearnRunnerPage extends ConsumerStatefulWidget {
  const LearnRunnerPage({super.key, required this.areaId, required this.cards, required this.sessions});

  final String areaId;
  final List<Flashcard> cards;
  final List<StudySession> sessions;

  @override
  ConsumerState<LearnRunnerPage> createState() => _LearnRunnerPageState();
}

class _LearnRunnerPageState extends ConsumerState<LearnRunnerPage> {
  late final List<ExamQuestion> _questions = [
    for (final card in learningOrder(widget.cards, answerStats(widget.sessions), Random())) questionForCard(card),
  ];
  final _answers = <StudyAnswer>[];
  final _started = DateTime.now();
  var _saved = false;

  late final LearningRepository _repository = ref.read(learningRepositoryProvider);

  @override
  void initState() {
    super.initState();
    // Früh lesen: beim Verlassen der Seite ist `ref` nicht mehr nutzbar.
    _repository;
  }

  Future<void> _save() async {
    if (_saved || _answers.isEmpty) return;
    _saved = true;
    await _repository.saveSession(
          areaId: widget.areaId,
          mode: StudyMode.learn,
          startedAt: _started,
          duration: DateTime.now().difference(_started),
          answers: _answers,
        );
  }

  void _answer(bool correct) {
    final question = _questions[_answers.length];
    setState(() => _answers.add(StudyAnswer(source: question.source, itemId: question.itemId, correct: correct)));
    if (_answers.length == _questions.length) _save();
  }

  @override
  Widget build(BuildContext context) {
    final done = _answers.length >= _questions.length;
    final correct = _answers.where((a) => a.correct).length;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(done ? 'Fertig' : 'Karte ${_answers.length + 1} von ${_questions.length}'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: _questions.isEmpty ? 1 : _answers.length / _questions.length),
          ),
        ),
        body: done
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$correct von ${_questions.length} gewusst', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zurück')),
                  ],
                ),
              )
            : QuestionView(question: _questions[_answers.length], onAnswered: _answer),
      ),
    );
  }
}

/// Prüfung mit Zeitlimit und Ergebnisübersicht.
class ExamRunnerPage extends ConsumerStatefulWidget {
  const ExamRunnerPage({
    super.key,
    required this.areaId,
    required this.cards,
    required this.glossary,
    required this.setup,
  });

  final String areaId;
  final List<Flashcard> cards;
  final List<GlossaryEntry> glossary;
  final ExamSetup setup;

  @override
  ConsumerState<ExamRunnerPage> createState() => _ExamRunnerPageState();
}

class _ExamRunnerPageState extends ConsumerState<ExamRunnerPage> {
  late final List<ExamQuestion> _questions = buildExam(
    cards: widget.cards,
    glossary: widget.glossary,
    includeCards: widget.setup.includeCards,
    includeGlossary: widget.setup.includeGlossary,
    count: widget.setup.count,
    random: Random(),
  );
  final _answers = <int, bool>{};
  final _started = DateTime.now();
  var _index = 0;
  ExamResult? _result;
  Timer? _ticker;

  Duration? get _limit => widget.setup.minutes == 0 ? null : Duration(minutes: widget.setup.minutes);

  @override
  void initState() {
    super.initState();
    if (_limit != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = remainingTime(startedAt: _started, limit: _limit, now: DateTime.now());
        if (left == Duration.zero) {
          _finish();
        } else if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_result != null) return;
    _ticker?.cancel();
    if (!mounted) return;
    final result = scoreExam(_questions, _answers, widget.setup.passPercent);
    final repository = ref.read(learningRepositoryProvider);
    setState(() => _result = result);
    await repository.saveSession(
          areaId: widget.areaId,
          mode: StudyMode.exam,
          startedAt: _started,
          duration: DateTime.now().difference(_started),
          answers: result.answers,
          passPercent: widget.setup.passPercent,
        );
  }

  void _answer(bool correct) {
    _answers[_index] = correct;
    if (_index + 1 >= _questions.length) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final left = remainingTime(startedAt: _started, limit: _limit, now: DateTime.now());
    String clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

    if (result != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ergebnis')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: result.passed ? const Color(0xFF2E9E6B).withValues(alpha: 0.2) : theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(result.passed ? 'Bestanden' : 'Nicht bestanden', style: theme.textTheme.headlineMedium),
                    Text('${result.correct} von ${result.total} richtig · ${(result.rate * 100).round()} % '
                        '(Grenze ${result.passPercent} %)'),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < _questions.length; i++)
              ListTile(
                leading: Icon(
                  result.answers[i].correct ? Icons.check_circle : Icons.cancel,
                  color: result.answers[i].correct ? const Color(0xFF2E9E6B) : theme.colorScheme.error,
                ),
                title: Text(_questions[i].prompt),
                subtitle: Text(
                  '${_answers.containsKey(i) ? '' : 'Nicht beantwortet · '}Richtig: ${_questions[i].answerText}',
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fertig')),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Keine Fragen in den gewählten Quellen.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Frage ${_index + 1} von ${_questions.length}'),
        actions: [
          if (left != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(clock(left), style: theme.textTheme.titleMedium),
              ),
            ),
          TextButton(onPressed: _finish, child: const Text('Abgeben')),
        ],
      ),
      body: QuestionView(question: _questions[_index], onAnswered: _answer),
    );
  }
}
