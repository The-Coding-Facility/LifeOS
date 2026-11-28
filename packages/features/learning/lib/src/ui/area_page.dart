import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_notes/lifeos_notes.dart';

import '../model.dart';
import '../providers.dart';
import '../study_logic.dart';
import 'card_dialogs.dart';
import 'learning_page.dart';
import 'runners.dart';

/// Ein Lernbereich mit den Reitern Lernen, Karten, Glossar, Notizen,
/// Ressourcen und Statistik.
class LearningAreaPage extends ConsumerWidget {
  const LearningAreaPage({super.key, required this.areaId});

  final String areaId;

  Future<void> _delete(BuildContext context, WidgetRef ref, LearningArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${area.name}“ löschen?'),
        content: const Text('Der Bereich verschwindet auf allen Geräten. Karten und Glossar sind dann nicht mehr erreichbar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(learningRepositoryProvider).deleteArea(area.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = (ref.watch(learningAreasProvider).value ?? const <LearningArea>[]).where((a) => a.id == areaId).firstOrNull;
    if (area == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.school_outlined, message: 'Diesen Lernbereich gibt es nicht mehr.'));
    }
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(area.name),
          actions: [
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => editLearningArea(context, ref, area: area),
            ),
            IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, area)),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Lernen'),
              Tab(text: 'Karten'),
              Tab(text: 'Glossar'),
              Tab(text: 'Notizen'),
              Tab(text: 'Ressourcen'),
              Tab(text: 'Statistik'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StudyTab(areaId: area.id),
            _CardsTab(areaId: area.id),
            _GlossaryTab(areaId: area.id),
            _NotesTab(areaId: area.id),
            _ResourcesTab(areaId: area.id),
            _StatsTab(areaId: area.id),
          ],
        ),
      ),
    );
  }
}

class _StudyTab extends ConsumerWidget {
  const _StudyTab({required this.areaId});

  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cards = ref.watch(flashcardsProvider(areaId)).value ?? const <Flashcard>[];
    final glossary = ref.watch(glossaryProvider(areaId)).value ?? const <GlossaryEntry>[];
    final sessions = [
      for (final s in ref.watch(studySessionsProvider).value ?? const <StudySession>[]) if (s.areaId == areaId) s,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.style_outlined, size: 32),
            title: const Text('Lernen'),
            subtitle: Text('${cards.length} Karten durchgehen, selbst bewerten'),
            trailing: const Icon(Icons.play_arrow),
            enabled: cards.isNotEmpty,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => LearnRunnerPage(areaId: areaId, cards: cards, sessions: sessions)),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.quiz_outlined, size: 32),
            title: const Text('Prüfung'),
            subtitle: Text('Aus ${cards.length} Karten und ${glossary.length} Begriffen, mit Zeitlimit'),
            trailing: const Icon(Icons.play_arrow),
            enabled: cards.isNotEmpty || glossary.isNotEmpty,
            onTap: () async {
              final setup = await showExamSetup(context, cardCount: cards.length, glossaryCount: glossary.length);
              if (setup == null || !context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExamRunnerPage(areaId: areaId, cards: cards, glossary: glossary, setup: setup),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Letzte Einheiten', style: theme.textTheme.titleMedium),
        if (sessions.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine.')),
        for (final session in sessions.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(session.mode == StudyMode.exam ? Icons.quiz_outlined : Icons.style_outlined),
            title: Text('${session.mode.label} · ${session.correct} von ${session.total} richtig'),
            subtitle: Text(
              '${formatDateShort(session.startedAt)} ${formatTime(session.startedAt)}'
              '${session.passed == null ? '' : session.passed! ? ' · bestanden' : ' · nicht bestanden'}',
            ),
          ),
      ],
    );
  }
}

class _CardsTab extends ConsumerWidget {
  const _CardsTab({required this.areaId});

  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(flashcardsProvider(areaId)).value ?? const <Flashcard>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Karte',
        onPressed: () => editFlashcard(context, ref, areaId),
        child: const Icon(Icons.add),
      ),
      body: cards.isEmpty
          ? const EmptyState(icon: Icons.style_outlined, message: 'Noch keine Karten.')
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final card in cards)
                  ListTile(
                    leading: Icon(card.kind == CardKind.choice ? Icons.checklist : Icons.short_text),
                    title: Text(card.question),
                    subtitle: Text(card.correctAnswerText, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => editFlashcard(context, ref, areaId, card: card),
                  ),
              ],
            ),
    );
  }
}

class _GlossaryTab extends ConsumerStatefulWidget {
  const _GlossaryTab({required this.areaId});

  final String areaId;

  @override
  ConsumerState<_GlossaryTab> createState() => _GlossaryTabState();
}

class _GlossaryTabState extends ConsumerState<_GlossaryTab> {
  var _query = '';

  Future<void> _edit({GlossaryEntry? entry}) async {
    final result = await showTextPairDialog(
      context,
      title: entry == null ? 'Neuer Begriff' : 'Begriff bearbeiten',
      firstLabel: 'Begriff',
      secondLabel: 'Erklärung',
      first: entry?.term ?? '',
      second: entry?.explanation ?? '',
      canDelete: entry != null,
    );
    if (result == null) return;
    final repository = ref.read(learningRepositoryProvider);
    if (result.delete && entry != null) {
      await repository.deleteGlossary(entry.id);
    } else if (entry == null) {
      await repository.addGlossary(widget.areaId, term: result.first, explanation: result.second);
    } else {
      await repository.updateGlossary(entry, term: result.first, explanation: result.second);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(glossaryProvider(widget.areaId)).value ?? const <GlossaryEntry>[];
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final entry in entries)
        if (query.isEmpty || entry.term.toLowerCase().contains(query) || entry.explanation.toLowerCase().contains(query))
          entry,
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton(tooltip: 'Neuer Begriff', onPressed: _edit, child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Im Glossar suchen'),
            onChanged: (value) => setState(() => _query = value),
          ),
          if (visible.isEmpty) const EmptyState(icon: Icons.menu_book_outlined, message: 'Keine Begriffe.'),
          for (final entry in visible)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.term),
              subtitle: Text(entry.explanation),
              onTap: () => _edit(entry: entry),
            ),
        ],
      ),
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.areaId});

  final String areaId;

  void _open(BuildContext context, String noteId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => NoteEditorPage(noteId: noteId, onClose: () => Navigator.of(routeContext).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(learningAreaNotesProvider(areaId)).value ?? const <NoteItem>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Notiz',
        onPressed: () async {
          final id = await ref.read(noteRepositoryProvider).create(learningAreaId: areaId);
          if (context.mounted) _open(context, id);
        },
        child: const Icon(Icons.add),
      ),
      body: notes.isEmpty
          ? const EmptyState(icon: Icons.sticky_note_2_outlined, message: 'Noch keine Notizen.')
          : ListView(
              children: [
                for (final note in notes)
                  ListTile(
                    title: Text(note.displayTitle),
                    subtitle: note.preview.isEmpty ? null : Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _open(context, note.id),
                  ),
              ],
            ),
    );
  }
}

class _ResourcesTab extends ConsumerWidget {
  const _ResourcesTab({required this.areaId});

  final String areaId;

  Future<void> _edit(BuildContext context, WidgetRef ref, {LearningResource? resource}) async {
    final result = await showTextPairDialog(
      context,
      title: resource == null ? 'Neue Ressource' : 'Ressource bearbeiten',
      firstLabel: 'Titel',
      secondLabel: 'Link oder Fundort',
      thirdLabel: 'Notiz',
      first: resource?.title ?? '',
      second: resource?.link ?? '',
      third: resource?.note ?? '',
      canDelete: resource != null,
    );
    if (result == null) return;
    final repository = ref.read(learningRepositoryProvider);
    if (result.delete && resource != null) {
      await repository.deleteResource(resource.id);
    } else if (resource == null) {
      await repository.addResource(areaId, title: result.first, link: result.second, note: result.third);
    } else {
      await repository.updateResource(resource, title: result.first, link: result.second, note: result.third);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(learningResourcesProvider(areaId)).value ?? const <LearningResource>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Ressource',
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: resources.isEmpty
          ? const EmptyState(icon: Icons.link, message: 'Noch keine Ressourcen, z. B. Bücher, Kurse oder Links.')
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final resource in resources)
                  ListTile(
                    title: Text(resource.title),
                    subtitle: Text([resource.link, resource.note].where((t) => t.isNotEmpty).join('\n')),
                    isThreeLine: resource.link.isNotEmpty && resource.note.isNotEmpty,
                    trailing: resource.link.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Link kopieren',
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: resource.link));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link kopiert')));
                              }
                            },
                          ),
                    onTap: () => _edit(context, ref, resource: resource),
                  ),
              ],
            ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.areaId});

  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = [
      for (final s in ref.watch(studySessionsProvider).value ?? const <StudySession>[]) if (s.areaId == areaId) s,
    ];
    final cards = {for (final c in ref.watch(flashcardsProvider(areaId)).value ?? const <Flashcard>[]) c.id: c};
    final glossary = {for (final g in ref.watch(glossaryProvider(areaId)).value ?? const <GlossaryEntry>[]) g.id: g};
    final now = DateTime.now();
    final last30 = sessions.where((s) => now.difference(s.startedAt).inDays < 30).length;
    final trend = studyTrend(sessions);
    final exams = sessions.where((s) => s.mode == StudyMode.exam).take(5).toList();
    final missed = mostMissed(sessions);
    final rates = [for (final s in sessions.reversed.take(30)) (s.rate * 100).round()];

    String labelFor(String key) {
      final id = key.substring(key.indexOf(':') + 1);
      if (key.startsWith('glossary:')) return glossary[id]?.term ?? 'Gelöschter Begriff';
      return cards[id]?.question ?? 'Gelöschte Karte';
    }

    if (sessions.isEmpty) {
      return const EmptyState(icon: Icons.insights_outlined, message: 'Noch keine Lerneinheiten.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Stat(label: 'Einheiten (30 Tage)', value: '$last30'),
            _Stat(label: 'Zuletzt richtig', value: '${(sessions.first.rate * 100).round()} %'),
            _Stat(
              label: 'Entwicklung',
              value: trend == null ? '–' : '${trend >= 0 ? '+' : ''}$trend Punkte',
              color: trend == null ? null : (trend >= 0 ? const Color(0xFF2E9E6B) : theme.colorScheme.error),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Trefferquote je Einheit',
          icon: Icons.show_chart,
          child: LineChartView(values: rates, formatValue: (v) => '$v %', startLabel: 'älter', endLabel: 'neueste'),
        ),
        const SizedBox(height: 16),
        Text('Letzte Prüfungen', style: theme.textTheme.titleMedium),
        if (exams.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Prüfung.')),
        for (final exam in exams)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(exam.passed == true ? Icons.check_circle : Icons.cancel,
                color: exam.passed == true ? const Color(0xFF2E9E6B) : theme.colorScheme.error),
            title: Text('${exam.correct} von ${exam.total} richtig (${(exam.rate * 100).round()} %)'),
            subtitle: Text('${formatDate(exam.startedAt)} · Grenze ${exam.passPercent} %'),
          ),
        const SizedBox(height: 16),
        Text('Am häufigsten falsch', style: theme.textTheme.titleMedium),
        if (missed.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Bisher nichts falsch.')),
        for (final item in missed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(labelFor(item.key)),
            trailing: Text('${item.wrong}× falsch'),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
