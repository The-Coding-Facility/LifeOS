import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../model.dart';
import '../providers.dart';
import '../report_math.dart';

/// Daily Report: Bericht eines Tages ausfüllen und Verlauf ansehen.
class DailyReportPage extends ConsumerStatefulWidget {
  const DailyReportPage({super.key, this.clock});

  /// Für Tests; sonst die Systemzeit.
  final DateTime Function()? clock;

  @override
  ConsumerState<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends ConsumerState<DailyReportPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _successes = TextEditingController();
  final _learned = TextEditingController();
  final _activities = TextEditingController();
  late DateTime _date = _today;
  var _calendarDone = false;
  var _kcal = false;
  var _water = false;
  int? _sleptAt;
  int? _wokeAt;
  var _exists = false;

  /// Tag, dessen Werte gerade im Formular stehen (`yyyy-mm-dd`).
  String? _filledFor;
  var _fillScheduled = false;

  DateTime get _today => dateOnly((widget.clock ?? DateTime.now)());

  @override
  void dispose() {
    _tabs.dispose();
    _successes.dispose();
    _learned.dispose();
    _activities.dispose();
    super.dispose();
  }

  bool get _loading => _filledFor != isoDate(_date);

  void _showDay(DateTime date) => setState(() => _date = dateOnly(date));

  /// Übernimmt den gespeicherten Bericht des gewählten Tages ins Formular.
  /// Die Berichte werden beobachtet (nicht nur einmal gelesen), sonst
  /// pausiert Riverpod die Datenquelle und das Laden endet nie.
  void _scheduleFill(List<DailyReport> reports) {
    if (_fillScheduled || !_loading) return;
    _fillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillScheduled = false;
      if (!mounted) return;
      final key = isoDate(_date);
      final report = reports.where((r) => isoDate(r.date) == key).firstOrNull;
      setState(() {
        _exists = report != null;
        _successes.text = report?.successes ?? '';
        _learned.text = report?.learned ?? '';
        _activities.text = report?.activities ?? '';
        _calendarDone = report?.calendarDone ?? false;
        _kcal = report?.kcalGoalMet ?? false;
        _water = report?.waterGoalMet ?? false;
        _sleptAt = report?.sleptAt;
        _wokeAt = report?.wokeAt;
        _filledFor = key;
      });
    });
  }

  Future<void> _save() async {
    await ref.read(dailyReportRepositoryProvider).save(
          DailyReport(
            date: _date,
            successes: _successes.text,
            learned: _learned.text,
            calendarDone: _calendarDone,
            kcalGoalMet: _kcal,
            waterGoalMet: _water,
            sleptAt: _sleptAt,
            wokeAt: _wokeAt,
            activities: _activities.text,
          ),
        );
    if (!mounted) return;
    setState(() => _exists = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bericht für ${formatDate(_date)} gespeichert')),
    );
  }

  Future<void> _pickClock({required bool slept}) async {
    final current = slept ? _sleptAt : _wokeAt;
    final fallback = slept ? 23 * 60 : 7 * 60;
    final minutes = current ?? fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: slept ? 'Schlafen gegangen' : 'Aufgestanden',
    );
    if (picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (slept) {
        _sleptAt = value;
      } else {
        _wokeAt = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(dailyReportsProvider).value;
    if (reports != null) _scheduleFill(reports);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Bericht'), Tab(text: 'Verlauf')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildForm(context),
          _History(
            today: _today,
            onOpen: (date) {
              _tabs.animateTo(0);
              _showDay(date);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
    final dayEvents = expandAll(events, _date, DateTime(_date.year, _date.month, _date.day + 1));
    final sleep = sleepDuration(_sleptAt, _wokeAt);
    final isToday = isoDate(_date) == isoDate(_today);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Vortag',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _showDay(DateTime(_date.year, _date.month, _date.day - 1)),
            ),
            Expanded(
              child: Text(
                isToday ? 'Heute, ${formatDate(_date)}' : formatDateLong(_date),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Nächster Tag',
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday ? null : () => _showDay(DateTime(_date.year, _date.month, _date.day + 1)),
            ),
          ],
        ),
        Center(
          child: Chip(
            avatar: Icon(_exists ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
            label: Text(_exists ? 'Gespeichert' : 'Noch nicht ausgefüllt'),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        TextField(
          controller: _successes,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Erfolge', prefixIcon: Icon(Icons.emoji_events_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _learned,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Gelerntes', prefixIcon: Icon(Icons.lightbulb_outline)),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kalender abgearbeitet'),
          subtitle: Text(
            dayEvents.isEmpty ? 'Keine Termine an diesem Tag' : '${dayEvents.length} Termine an diesem Tag',
          ),
          value: _calendarDone,
          onChanged: (value) => setState(() => _calendarDone = value ?? false),
        ),
        for (final occurrence in dayEvents)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '${occurrence.allDay ? 'ganztägig' : formatTime(occurrence.start)}  ${occurrence.event.title}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('kcal-Ziel erreicht'),
          value: _kcal,
          onChanged: (value) => setState(() => _kcal = value ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wasser-Ziel erreicht'),
          value: _water,
          onChanged: (value) => setState(() => _water = value ?? false),
        ),
        const SizedBox(height: 8),
        Text('Schlaf', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickClock(slept: true),
              icon: const Icon(Icons.bedtime_outlined),
              label: Text(_sleptAt == null ? 'Schlafen gegangen' : 'Geschlafen ab ${formatClock(_sleptAt!)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickClock(slept: false),
              icon: const Icon(Icons.wb_sunny_outlined),
              label: Text(_wokeAt == null ? 'Aufgestanden' : 'Aufgestanden um ${formatClock(_wokeAt!)}'),
            ),
            if (sleep != null) Text('= ${formatDuration(sleep)} Schlaf', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _activities,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Besondere Aktivitäten', prefixIcon: Icon(Icons.star_outline)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.today, required this.onOpen});

  final DateTime today;
  final ValueChanged<DateTime> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reports = ref.watch(dailyReportsProvider).value ?? const <DailyReport>[];
    final streak = reportStreak(reports.map((r) => r.date), today);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(streak == 1 ? '1 Tag in Folge' : '$streak Tage in Folge'),
            subtitle: Text('${reports.length} Berichte insgesamt'),
          ),
        ),
        if (reports.isEmpty)
          const EmptyState(icon: Icons.edit_note, message: 'Noch keine Berichte.'),
        for (final report in reports)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(formatDateLong(report.date)),
            subtitle: Text(
              [
                if (report.successes.isNotEmpty) report.successes.split('\n').first,
                [
                  if (report.calendarDone) 'Kalender ✓',
                  if (report.kcalGoalMet) 'kcal ✓',
                  if (report.waterGoalMet) 'Wasser ✓',
                  if (report.sleep != null) 'Schlaf ${formatDuration(report.sleep!)}',
                ].join(' · '),
              ].where((line) => line.isNotEmpty).join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onOpen(report.date),
          ),
        if (reports.isNotEmpty) Text('Antippen öffnet den Bericht.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
