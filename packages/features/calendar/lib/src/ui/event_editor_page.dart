import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model/event.dart';
import '../model/recurrence.dart';
import '../occurrences.dart';
import '../providers.dart';
import '../reminder_planner.dart';
import '../series_edit.dart';
import 'series_choice.dart';

/// Öffnet das Formular für einen neuen Termin ab [initialStart] oder zum
/// Bearbeiten von [occurrence].
Future<void> openEventEditor(
  BuildContext context, {
  Occurrence? occurrence,
  DateTime? initialStart,
  bool initialAllDay = false,
  String? initialProjectId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventEditorPage(
        occurrence: occurrence,
        initialStart: initialStart,
        initialAllDay: initialAllDay,
        initialProjectId: initialProjectId,
      ),
    ),
  );
}

/// Formular für einen Termin.
class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({
    super.key,
    this.occurrence,
    this.initialStart,
    this.initialAllDay = false,
    this.initialProjectId,
  });

  final Occurrence? occurrence;
  final DateTime? initialStart;
  final bool initialAllDay;
  final String? initialProjectId;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late bool _allDay;
  late DateTime _start;
  late DateTime _end;
  RecurrenceFreq? _freq;
  int _interval = 1;
  Set<int> _weekdays = {};
  DateTime? _until;
  List<String> _tagIds = [];
  int? _reminder;
  List<String> _devices = [allDevices];
  String? _projectId;
  String? _trainingPlanId;
  var _saving = false;

  CalendarEvent? get _event => widget.occurrence?.event;
  bool get _isNew => widget.occurrence == null;

  @override
  void initState() {
    super.initState();
    final occurrence = widget.occurrence;
    if (occurrence != null) {
      final draft = EventDraft.fromEvent(occurrence.event, occurrenceStart: occurrence.start);
      _title = TextEditingController(text: draft.title);
      _location = TextEditingController(text: draft.location ?? '');
      _description = TextEditingController(text: draft.description ?? '');
      _allDay = draft.allDay;
      _start = draft.start;
      _end = draft.end;
      final recurrence = draft.recurrence;
      if (recurrence != null) {
        _freq = recurrence.freq;
        _interval = recurrence.interval;
        _weekdays = {...recurrence.weekdays};
        _until = recurrence.until;
      }
      _tagIds = [...draft.tagIds];
      _reminder = draft.reminderMinutes;
      _devices = [...draft.reminderDevices];
      _projectId = draft.projectId;
      _trainingPlanId = draft.trainingPlanId;
    } else {
      _projectId = widget.initialProjectId;
      final now = DateTime.now();
      final start = widget.initialStart ?? DateTime(now.year, now.month, now.day, now.hour + 1);
      _title = TextEditingController();
      _location = TextEditingController();
      _description = TextEditingController();
      _allDay = widget.initialAllDay;
      _start = _allDay ? dateOnly(start) : start;
      _end = _allDay ? dateOnly(start) : start.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Recurrence? get _recurrence => _freq == null
      ? null
      : Recurrence(
          freq: _freq!,
          interval: _interval,
          weekdays: _freq == RecurrenceFreq.weekly ? _weekdays : const {},
          until: _until,
        );

  EventDraft _draft() => EventDraft(
        title: _title.text,
        description: _description.text,
        location: _location.text,
        allDay: _allDay,
        start: _start,
        end: _end,
        recurrence: _recurrence,
        tagIds: _tagIds,
        // Ohne gewähltes Gerät gibt es keine Erinnerung.
        reminderMinutes: _devices.isEmpty ? null : _reminder,
        reminderDevices: _devices.isEmpty ? const [allDevices] : _devices,
        projectId: _projectId,
        trainingPlanId: _trainingPlanId,
      );

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _showMessage('Bitte gib einen Titel ein.');
      return;
    }
    if (_end.isBefore(_start)) {
      _showMessage('Das Ende liegt vor dem Beginn.');
      return;
    }
    final repository = ref.read(eventRepositoryProvider);
    final draft = _draft();
    final occurrence = widget.occurrence;
    setState(() => _saving = true);
    try {
      if (occurrence == null) {
        await repository.create(draft);
      } else if (!occurrence.event.isRecurring) {
        await repository.update(occurrence.event.id, draft);
      } else {
        final choice = await askSeriesChoice(context, title: 'Änderung speichern');
        if (choice == null) return;
        if (choice == SeriesChoice.onlyThis) {
          await repository.detachOccurrence(occurrence.event.id, occurrence.dateKey, draft);
        } else {
          await repository.update(
            occurrence.event.id,
            applyToSeries(series: occurrence.event, occurrenceStart: occurrence.start, edited: draft),
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final occurrence = widget.occurrence;
    if (occurrence == null) return;
    final repository = ref.read(eventRepositoryProvider);
    if (occurrence.event.isRecurring) {
      final choice = await askSeriesChoice(context, title: 'Termin löschen');
      if (choice == null) return;
      if (choice == SeriesChoice.onlyThis) {
        await repository.excludeOccurrence(occurrence.event.id, occurrence.dateKey);
      } else {
        await repository.delete(occurrence.event.id);
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Termin löschen?'),
          content: Text('„${occurrence.event.title}“ wird auf allen Geräten gelöscht.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen')),
          ],
        ),
      );
      if (confirmed != true) return;
      await repository.delete(occurrence.event.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final updated = DateTime(picked.year, picked.month, picked.day, current.hour, current.minute);
      if (start) {
        final length = _end.difference(_start);
        _start = updated;
        _end = updated.add(length);
      } else {
        _end = updated;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (picked == null) return;
    setState(() {
      final updated = DateTime(current.year, current.month, current.day, picked.hour, picked.minute);
      if (start) {
        final length = _end.difference(_start);
        _start = updated;
        _end = updated.add(length);
      } else {
        _end = updated;
      }
    });
  }

  Future<void> _pickUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _until ?? _start.add(const Duration(days: 90)),
      firstDate: dateOnly(_start),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _until = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = ref.watch(deviceChoicesProvider).value ?? const <DeviceChoice>[];
    final projects = ref.watch(projectChoicesProvider).value ?? const <ProjectChoice>[];
    final plans = ref.watch(trainingPlanChoicesProvider).value ?? const <TrainingPlanChoice>[];
    final startTraining = ref.watch(startTrainingProvider);
    final savedPlanId = widget.occurrence?.event.trainingPlanId;
    final allSelected = _devices.contains(allDevices);

    Widget dateTimeRow(String label, {required bool start}) {
      final value = start ? _start : _end;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 64, child: Text(label, style: theme.textTheme.bodyLarge)),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(start: start),
                child: Text(formatDateShort(value) + value.year.toString()),
              ),
            ),
            if (!_allDay) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => _pickTime(start: start), child: Text(formatTime(value))),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Neuer Termin' : 'Termin bearbeiten'),
        actions: [
          if (savedPlanId != null && startTraining != null)
            TextButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                final root = navigator.context;
                navigator.pop();
                startTraining(root, savedPlanId);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Training starten'),
            ),
          if (!_isNew)
            IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _saving ? null : _save, child: const Text('Speichern')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Titel'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ganztägig'),
            value: _allDay,
            onChanged: (value) => setState(() {
              _allDay = value;
              if (value) {
                _start = dateOnly(_start);
                _end = dateOnly(_end);
              } else {
                _start = DateTime(_start.year, _start.month, _start.day, 9);
                _end = _start.add(const Duration(hours: 1));
              }
            }),
          ),
          dateTimeRow('Beginn', start: true),
          dateTimeRow('Ende', start: false),
          const SizedBox(height: 8),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Ort', prefixIcon: Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
          ),
          const SizedBox(height: 16),
          Text('Tags', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TagSelector(
            scope: TagScope.calendar,
            selectedIds: _tagIds,
            onChanged: (ids) => setState(() => _tagIds = ids),
          ),
          if (projects.isNotEmpty || _projectId != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _projectId,
              decoration: const InputDecoration(labelText: 'Projekt', prefixIcon: Icon(Icons.work_outline)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Kein Projekt')),
                for (final project in projects)
                  DropdownMenuItem<String?>(value: project.id, child: Text(project.name)),
                if (_projectId != null && !projects.any((p) => p.id == _projectId))
                  DropdownMenuItem<String?>(value: _projectId, child: const Text('Abgeschlossenes Projekt')),
              ],
              onChanged: (value) => setState(() => _projectId = value),
            ),
          ],
          if (plans.isNotEmpty || _trainingPlanId != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _trainingPlanId,
              decoration: const InputDecoration(
                labelText: 'Trainingsplan',
                prefixIcon: Icon(Icons.fitness_center),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Kein Training')),
                for (final plan in plans) DropdownMenuItem<String?>(value: plan.id, child: Text(plan.name)),
                if (_trainingPlanId != null && !plans.any((p) => p.id == _trainingPlanId))
                  DropdownMenuItem<String?>(value: _trainingPlanId, child: const Text('Gelöschter Plan')),
              ],
              onChanged: (value) => setState(() => _trainingPlanId = value),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<RecurrenceFreq?>(
            initialValue: _freq,
            decoration: const InputDecoration(labelText: 'Wiederholen', prefixIcon: Icon(Icons.repeat)),
            items: [
              const DropdownMenuItem<RecurrenceFreq?>(value: null, child: Text('Nie')),
              for (final freq in RecurrenceFreq.values)
                DropdownMenuItem<RecurrenceFreq?>(value: freq, child: Text(freq.label)),
            ],
            onChanged: (freq) => setState(() {
              _freq = freq;
              if (freq == RecurrenceFreq.weekly && _weekdays.isEmpty) _weekdays = {_start.weekday};
            }),
          ),
          if (_freq != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Alle'),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _interval > 1 ? () => setState(() => _interval--) : null,
                ),
                Text('$_interval', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _interval < 99 ? () => setState(() => _interval++) : null,
                ),
                Text(switch (_freq!) {
                  RecurrenceFreq.daily => _interval == 1 ? 'Tag' : 'Tage',
                  RecurrenceFreq.weekly => _interval == 1 ? 'Woche' : 'Wochen',
                  RecurrenceFreq.monthly => _interval == 1 ? 'Monat' : 'Monate',
                  RecurrenceFreq.yearly => _interval == 1 ? 'Jahr' : 'Jahre',
                }),
              ],
            ),
            if (_freq == RecurrenceFreq.weekly)
              Wrap(
                spacing: 6,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(germanWeekdaysShort[day - 1]),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() {
                        final next = {..._weekdays};
                        selected ? next.add(day) : next.remove(day);
                        if (next.isNotEmpty) _weekdays = next;
                      }),
                    ),
                ],
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Endet'),
              subtitle: Text(_until == null ? 'Nie' : 'Am ${formatDate(_until!)}'),
              onTap: _pickUntil,
              trailing: _until == null
                  ? const Icon(Icons.event)
                  : IconButton(
                      tooltip: 'Ohne Ende',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _until = null),
                    ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _reminder,
            decoration: const InputDecoration(
              labelText: 'Erinnerung',
              prefixIcon: Icon(Icons.notifications_outlined),
            ),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(describeReminder(null))),
              for (final minutes in reminderChoices)
                DropdownMenuItem<int?>(value: minutes, child: Text(describeReminder(minutes))),
            ],
            onChanged: (value) => setState(() => _reminder = value),
          ),
          if (_reminder != null) ...[
            const SizedBox(height: 8),
            Text('Erinnern auf', style: theme.textTheme.titleSmall),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allen Geräten'),
              value: allSelected,
              onChanged: (value) => setState(() {
                _devices = value == true
                    ? [allDevices]
                    : [for (final device in devices) if (device.isThisDevice) device.id];
              }),
            ),
            for (final device in devices)
              CheckboxListTile(
                contentPadding: const EdgeInsets.only(left: 16),
                title: Text(device.isThisDevice ? '${device.name} (dieses Gerät)' : device.name),
                value: allSelected || _devices.contains(device.id),
                onChanged: allSelected
                    ? null
                    : (value) => setState(() {
                          final next = [..._devices.where((id) => id != device.id)];
                          if (value == true) next.add(device.id);
                          _devices = next;
                        }),
              ),
            if (!allSelected && _devices.isEmpty)
              Text(
                'Ohne Gerät wird keine Erinnerung gespeichert.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
          ],
          if (_event?.isRecurring ?? false) ...[
            const SizedBox(height: 16),
            Text(
              'Teil einer Serie: ${_event!.recurrence!.describe()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
