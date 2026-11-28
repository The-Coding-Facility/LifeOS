import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model.dart';
import '../providers.dart';

/// Karte anlegen oder bearbeiten (Text oder Multiple Choice).
Future<void> editFlashcard(BuildContext context, WidgetRef ref, String areaId, {Flashcard? card}) async {
  final result = await showDialog<_CardResult>(context: context, builder: (_) => _CardDialog(card: card));
  if (result == null) return;
  final repository = ref.read(learningRepositoryProvider);
  if (result.delete && card != null) {
    await repository.deleteCard(card.id);
  } else if (card == null) {
    await repository.addCard(areaId, question: result.question, kind: result.kind, answer: result.answer, choices: result.choices);
  } else {
    await repository.updateCard(card, question: result.question, kind: result.kind, answer: result.answer, choices: result.choices);
  }
}

class _CardResult {
  const _CardResult({required this.question, required this.kind, this.answer = '', this.choices = const []})
      : delete = false;

  const _CardResult.delete()
      : question = '',
        kind = CardKind.text,
        answer = '',
        choices = const [],
        delete = true;

  final String question;
  final CardKind kind;
  final String answer;
  final List<Choice> choices;
  final bool delete;
}

class _ChoiceRow {
  _ChoiceRow(String text, this.correct) : controller = TextEditingController(text: text);

  final TextEditingController controller;
  bool correct;
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({this.card});

  final Flashcard? card;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final _question = TextEditingController(text: widget.card?.question ?? '');
  late final _answer = TextEditingController(text: widget.card?.answer ?? '');
  late var _kind = widget.card?.kind ?? CardKind.text;
  late final List<_ChoiceRow> _choices = [
    for (final choice in widget.card?.choices ?? const <Choice>[]) _ChoiceRow(choice.text, choice.correct),
  ];
  String? _error;

  @override
  void initState() {
    super.initState();
    while (_choices.length < 2) {
      _choices.add(_ChoiceRow('', _choices.isEmpty));
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    for (final row in _choices) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_question.text.trim().isEmpty) {
      setState(() => _error = 'Bitte eine Frage eingeben.');
      return;
    }
    final choices = [
      for (final row in _choices)
        if (row.controller.text.trim().isNotEmpty) Choice(text: row.controller.text.trim(), correct: row.correct),
    ];
    if (_kind == CardKind.choice && (choices.length < 2 || !choices.any((c) => c.correct))) {
      setState(() => _error = 'Mindestens zwei Antworten, davon mindestens eine richtig.');
      return;
    }
    Navigator.of(context).pop(
      _CardResult(question: _question.text.trim(), kind: _kind, answer: _answer.text.trim(), choices: choices),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.card == null ? 'Neue Karte' : 'Karte bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _question,
              autofocus: widget.card == null,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Frage'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CardKind>(
              showSelectedIcon: false,
              segments: [for (final kind in CardKind.values) ButtonSegment(value: kind, label: Text(kind.label))],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            const SizedBox(height: 8),
            if (_kind == CardKind.text)
              TextField(
                controller: _answer,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Antwort'),
              )
            else ...[
              Text('Antworten (Haken = richtig)', style: theme.textTheme.labelLarge),
              for (final row in _choices)
                Row(
                  children: [
                    Checkbox(value: row.correct, onChanged: (value) => setState(() => row.correct = value ?? false)),
                    Expanded(child: TextField(controller: row.controller, decoration: const InputDecoration(isDense: true))),
                    IconButton(
                      tooltip: 'Entfernen',
                      icon: const Icon(Icons.close),
                      onPressed: _choices.length <= 2
                          ? null
                          : () => setState(() {
                                _choices.remove(row);
                                row.controller.dispose();
                              }),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: () => setState(() => _choices.add(_ChoiceRow('', false))),
                icon: const Icon(Icons.add),
                label: const Text('Antwort hinzufügen'),
              ),
            ],
            if (_error != null)
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ),
      ),
      actions: [
        if (widget.card != null)
          TextButton(onPressed: () => Navigator.of(context).pop(const _CardResult.delete()), child: const Text('Löschen')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

/// Zwei Textfelder (z. B. Begriff + Erklärung) mit optionalem Löschen.
Future<({String first, String second, String third, bool delete})?> showTextPairDialog(
  BuildContext context, {
  required String title,
  required String firstLabel,
  required String secondLabel,
  String? thirdLabel,
  String first = '',
  String second = '',
  String third = '',
  bool canDelete = false,
}) {
  return showDialog<({String first, String second, String third, bool delete})>(
    context: context,
    builder: (context) => _TextPairDialog(
      title: title,
      firstLabel: firstLabel,
      secondLabel: secondLabel,
      thirdLabel: thirdLabel,
      first: first,
      second: second,
      third: third,
      canDelete: canDelete,
    ),
  );
}

class _TextPairDialog extends StatefulWidget {
  const _TextPairDialog({
    required this.title,
    required this.firstLabel,
    required this.secondLabel,
    required this.thirdLabel,
    required this.first,
    required this.second,
    required this.third,
    required this.canDelete,
  });

  final String title;
  final String firstLabel;
  final String secondLabel;
  final String? thirdLabel;
  final String first;
  final String second;
  final String third;
  final bool canDelete;

  @override
  State<_TextPairDialog> createState() => _TextPairDialogState();
}

class _TextPairDialogState extends State<_TextPairDialog> {
  late final _first = TextEditingController(text: widget.first);
  late final _second = TextEditingController(text: widget.second);
  late final _third = TextEditingController(text: widget.third);

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _third.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _first,
              autofocus: widget.first.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.firstLabel),
            ),
            TextField(
              controller: _second,
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(labelText: widget.secondLabel),
            ),
            if (widget.thirdLabel != null)
              TextField(
                controller: _third,
                minLines: 1,
                maxLines: 6,
                decoration: InputDecoration(labelText: widget.thirdLabel),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            onPressed: () => Navigator.of(context).pop((first: '', second: '', third: '', delete: true)),
            child: const Text('Löschen'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_first.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              (first: _first.text.trim(), second: _second.text.trim(), third: _third.text.trim(), delete: false),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
