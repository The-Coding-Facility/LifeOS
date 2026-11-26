import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_tags/lifeos_tags.dart';

import '../model.dart';
import '../providers.dart';

/// Öffnet das Formular für eine neue Buchung, eine bestehende Buchung
/// ([entry]) oder einen Dauerauftrag ([rule]).
Future<void> openEntryEditor(
  BuildContext context, {
  FinanceEntry? entry,
  RecurringRule? rule,
  EntryKind initialKind = EntryKind.expense,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EntryEditorPage(entry: entry, rule: rule, initialKind: initialKind),
    ),
  );
}

/// Formular für Buchungen und Daueraufträge.
class EntryEditorPage extends ConsumerStatefulWidget {
  const EntryEditorPage({super.key, this.entry, this.rule, this.initialKind = EntryKind.expense});

  final FinanceEntry? entry;
  final RecurringRule? rule;
  final EntryKind initialKind;

  @override
  ConsumerState<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends ConsumerState<EntryEditorPage> {
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late EntryKind _kind;
  late DateTime _date;
  late List<String> _tagIds;
  late bool _repeat;
  var _freq = RecurringFreq.monthly;
  var _interval = 1;
  DateTime? _endDate;
  String? _amountError;

  bool get _isNew => widget.entry == null && widget.rule == null;
  bool get _isRuleEdit => widget.rule != null;
  bool get _isGoalEntry => _kind == EntryKind.saving || _kind == EntryKind.withdrawal;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final rule = widget.rule;
    if (rule != null) {
      _kind = rule.kind;
      _amount = TextEditingController(text: _editableAmount(rule.amountCents));
      _title = TextEditingController(text: rule.title);
      _date = rule.startDate;
      _tagIds = [...rule.tagIds];
      _repeat = true;
      _freq = rule.freq;
      _interval = rule.interval;
      _endDate = rule.endDate;
    } else if (entry != null) {
      _kind = entry.kind;
      _amount = TextEditingController(text: _editableAmount(entry.amountCents));
      _title = TextEditingController(text: entry.title);
      _date = entry.date;
      _tagIds = [...entry.tagIds];
      _repeat = false;
    } else {
      _kind = widget.initialKind;
      _amount = TextEditingController();
      _title = TextEditingController();
      _date = dateOnly(DateTime.now());
      _tagIds = [];
      _repeat = false;
    }
  }

  static String _editableAmount(int cents) => formatCents(cents).replaceAll(' €', '').replaceAll('.', '');

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = parseCents(_amount.text)?.abs();
    if (cents == null || cents == 0) {
      setState(() => _amountError = 'Bitte einen Betrag eingeben, z. B. 12,50');
      return;
    }
    final repository = ref.read(financeRepositoryProvider);
    if (_repeat) {
      final draft = RecurringDraft(
        kind: _kind,
        amountCents: cents,
        title: _title.text,
        tagIds: _tagIds,
        freq: _freq,
        interval: _interval,
        startDate: _date,
        endDate: _endDate,
      );
      if (widget.rule == null) {
        await repository.addRecurring(draft);
      } else {
        await repository.updateRecurring(widget.rule!.id, draft);
      }
    } else {
      final draft = EntryDraft(
        kind: _kind,
        amountCents: cents,
        date: _date,
        title: _title.text,
        tagIds: _tagIds,
        savingGoalId: widget.entry?.savingGoalId,
      );
      if (widget.entry == null) {
        await repository.addEntry(draft);
      } else {
        await repository.updateEntry(widget.entry!.id, draft);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final isRule = _isRuleEdit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRule ? 'Dauerauftrag beenden?' : 'Buchung löschen?'),
        content: Text(
          isRule
              ? 'Es wird nichts mehr neu gebucht. Bereits gebuchte Beträge bleiben erhalten.'
              : 'Die Buchung wird auf allen Geräten gelöscht.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isRule ? 'Beenden' : 'Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = ref.read(financeRepositoryProvider);
    if (isRule) {
      await repository.deleteRecurring(widget.rule!.id);
    } else {
      await repository.deleteEntry(widget.entry!.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate({required bool end}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? (_endDate ?? _date) : _date,
      firstDate: end ? _date : DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _endDate = picked;
      } else {
        _date = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isRuleEdit
        ? 'Dauerauftrag'
        : _isNew
            ? 'Neue Buchung'
            : 'Buchung bearbeiten';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isNew)
            IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isGoalEntry)
            Text(_kind.label, style: theme.textTheme.titleMedium)
          else
            SegmentedButton<EntryKind>(
              segments: const [
                ButtonSegment(value: EntryKind.expense, label: Text('Ausgabe'), icon: Icon(Icons.remove)),
                ButtonSegment(value: EntryKind.income, label: Text('Einnahme'), icon: Icon(Icons.add)),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: _isNew,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(labelText: 'Betrag in €', errorText: _amountError),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Wofür?', hintText: 'z. B. Wocheneinkauf'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_repeat ? 'Erste Buchung am' : 'Datum'),
            subtitle: Text(formatDate(_date)),
            onTap: () => _pickDate(end: false),
          ),
          const SizedBox(height: 8),
          Text('Tags', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TagSelector(
            scope: TagScope.finance,
            selectedIds: _tagIds,
            onChanged: (ids) => setState(() => _tagIds = ids),
          ),
          if (_isNew || _isRuleEdit) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wiederholen (Dauerauftrag)'),
              value: _repeat,
              onChanged: _isRuleEdit ? null : (value) => setState(() => _repeat = value),
            ),
          ],
          if (_repeat) ...[
            DropdownButtonFormField<RecurringFreq>(
              initialValue: _freq,
              decoration: const InputDecoration(labelText: 'Rhythmus'),
              items: [
                for (final freq in RecurringFreq.values) DropdownMenuItem(value: freq, child: Text(freq.label)),
              ],
              onChanged: (freq) => setState(() => _freq = freq ?? _freq),
            ),
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
                Text(switch (_freq) {
                  RecurringFreq.weekly => _interval == 1 ? 'Woche' : 'Wochen',
                  RecurringFreq.monthly => _interval == 1 ? 'Monat' : 'Monate',
                  RecurringFreq.yearly => _interval == 1 ? 'Jahr' : 'Jahre',
                }),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy),
              title: const Text('Endet'),
              subtitle: Text(_endDate == null ? 'Nie' : 'Am ${formatDate(_endDate!)}'),
              onTap: () => _pickDate(end: true),
              trailing: _endDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Ohne Ende',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endDate = null),
                    ),
            ),
            Text(
              'Fällige Beträge bis heute werden sofort gebucht, weitere jeweils am Buchungstag.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
