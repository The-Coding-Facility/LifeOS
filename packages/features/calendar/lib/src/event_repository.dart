import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_persistence/lifeos_persistence.dart';

import 'model/event.dart';
import 'model/recurrence.dart';

/// Lesen und Schreiben von Terminen. Jede Änderung wird protokolliert.
///
/// Feldgruppen: `title`, `details` (Beschreibung, Ort), `time` (ganztägig,
/// Beginn, Ende), `recurrence` (Regel, Ausnahmen), `tags`, `reminder`,
/// `project`.
class EventRepository {
  EventRepository(this._db, this._recorder);

  static const String entity = 'calendar_events';

  final LifeosDatabase _db;
  final ChangeRecorder _recorder;

  /// Alle nicht gelöschten Termine.
  Stream<List<CalendarEvent>> watchAll() {
    final query = _db.select(_db.calendarEvents)
      ..where((event) => event.deletedHlc.isNull())
      ..orderBy([(event) => OrderingTerm.asc(event.startAt)]);
    return query.watch().map((rows) => rows.map(_toEvent).toList(growable: false));
  }

  Future<CalendarEvent?> find(String id) async {
    final row = await _findActive(id);
    return row == null ? null : _toEvent(row);
  }

  /// Legt einen Termin an und gibt seine ID zurück.
  Future<String> create(EventDraft draft) {
    return _db.transaction(() => _insert(draft));
  }

  /// Übernimmt die Formularwerte. Protokolliert nur geänderte Feldgruppen.
  Future<void> update(String id, EventDraft draft) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final wanted = _columnsOf(draft, exdates: _decodeList(current.exdates));
      final existing = _columnsOfRow(current);
      final groups = <String, Map<String, Object?>>{};
      for (final MapEntry(key: group, value: columns) in _groups.entries) {
        final changed = columns.any((column) => wanted[column] != existing[column]);
        if (changed) {
          groups[group] = {for (final column in columns) column: wanted[column]};
        }
      }
      if (groups.isEmpty) return;
      await _record(id, groups);
    });
  }

  /// Verschiebt einen Termin (bei Serien: die ganze Serie) so, dass er
  /// lokal um [newStart] beginnt. Die Dauer bleibt.
  Future<void> move(String id, DateTime newStart) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final draft = EventDraft.fromEvent(_toEvent(current));
      final shift = newStart.difference(draft.start);
      final moved = draft.copyWith(start: newStart, end: draft.end.add(shift));
      final wanted = _columnsOf(moved, exdates: _decodeList(current.exdates));
      if (wanted['start_at'] == current.startAt && wanted['end_at'] == current.endAt) return;
      await _record(id, {
        'time': {
          'all_day': current.allDay,
          'start_at': wanted['start_at'],
          'end_at': wanted['end_at'],
        },
      });
    });
  }

  /// Lässt ein Vorkommen einer Serie aus (Löschen „nur dieser Termin“).
  Future<void> excludeOccurrence(String id, String dateKey) {
    return _db.transaction(() => _exclude(id, dateKey));
  }

  /// Ändert ein einzelnes Vorkommen: Die Serie lässt es aus, und es entsteht
  /// ein eigener Termin mit den Werten aus [draft] (ohne Wiederholung).
  Future<String> detachOccurrence(String id, String dateKey, EventDraft draft) {
    return _db.transaction(() async {
      await _exclude(id, dateKey);
      return _insert(draft.copyWith(clearRecurrence: true));
    });
  }

  /// Löscht einen Termin (bei Serien: alle Vorkommen) als Tombstone.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final current = await _findActive(id);
      if (current == null) return;
      final hlc = await _recorder.record(
        entity: entity,
        recordId: id,
        op: ChangeOp.delete,
        groups: {
          deletedFieldGroup: {'deleted': true},
        },
      );
      await (_db.update(_db.calendarEvents)..where((event) => event.id.equals(id))).write(
        CalendarEventsCompanion(
          deletedHlc: Value(hlc.pack()),
          updatedHlc: Value(hlc.pack()),
          updatedBy: Value(_recorder.deviceId),
        ),
      );
    });
  }

  static const Map<String, List<String>> _groups = {
    'title': ['title'],
    'details': ['description', 'location'],
    'time': ['all_day', 'start_at', 'end_at'],
    'recurrence': ['recurrence', 'exdates'],
    'tags': ['tag_ids'],
    'reminder': ['reminder_minutes', 'reminder_devices'],
    'project': ['project_id'],
    'training_plan': ['training_plan_id'],
  };

  Future<String> _insert(EventDraft draft) async {
    final id = Ids.newId();
    final columns = _columnsOf(draft, exdates: const []);
    final hlc = await _recorder.record(
      entity: entity,
      recordId: id,
      op: ChangeOp.upsert,
      groups: {
        for (final MapEntry(key: group, value: names) in _groups.entries)
          group: {for (final name in names) name: columns[name]},
      },
    );
    await _db.into(_db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: id,
            title: columns['title']! as String,
            description: Value(columns['description'] as String?),
            location: Value(columns['location'] as String?),
            allDay: Value(columns['all_day']! as bool),
            startAt: columns['start_at']! as int,
            endAt: columns['end_at']! as int,
            recurrence: Value(columns['recurrence'] as String?),
            exdates: Value(columns['exdates']! as String),
            tagIds: Value(columns['tag_ids']! as String),
            reminderMinutes: Value(columns['reminder_minutes'] as int?),
            reminderDevices: Value(columns['reminder_devices']! as String),
            projectId: Value(columns['project_id'] as String?),
            trainingPlanId: Value(columns['training_plan_id'] as String?),
            createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            createdBy: _recorder.deviceId,
            updatedHlc: hlc.pack(),
            updatedBy: _recorder.deviceId,
          ),
        );
    return id;
  }

  Future<void> _exclude(String id, String dateKey) async {
    final current = await _findActive(id);
    if (current == null) return;
    final exdates = {..._decodeList(current.exdates), dateKey}.toList()..sort();
    final encoded = jsonEncode(exdates);
    if (encoded == current.exdates) return;
    await _record(id, {
      'recurrence': {'recurrence': current.recurrence, 'exdates': encoded},
    });
  }

  /// Protokolliert [groups] und schreibt dieselben Werte in die Zeile.
  Future<void> _record(String id, Map<String, Map<String, Object?>> groups) async {
    final hlc = await _recorder.record(
      entity: entity,
      recordId: id,
      op: ChangeOp.upsert,
      groups: groups,
    );
    final values = {for (final group in groups.values) ...group};
    await (_db.update(_db.calendarEvents)..where((event) => event.id.equals(id))).write(
      CalendarEventsCompanion(
        title: values.containsKey('title') ? Value(values['title']! as String) : const Value.absent(),
        description: values.containsKey('description')
            ? Value(values['description'] as String?)
            : const Value.absent(),
        location:
            values.containsKey('location') ? Value(values['location'] as String?) : const Value.absent(),
        allDay: values.containsKey('all_day') ? Value(values['all_day']! as bool) : const Value.absent(),
        startAt: values.containsKey('start_at') ? Value(values['start_at']! as int) : const Value.absent(),
        endAt: values.containsKey('end_at') ? Value(values['end_at']! as int) : const Value.absent(),
        recurrence: values.containsKey('recurrence')
            ? Value(values['recurrence'] as String?)
            : const Value.absent(),
        exdates: values.containsKey('exdates') ? Value(values['exdates']! as String) : const Value.absent(),
        tagIds: values.containsKey('tag_ids') ? Value(values['tag_ids']! as String) : const Value.absent(),
        reminderMinutes: values.containsKey('reminder_minutes')
            ? Value(values['reminder_minutes'] as int?)
            : const Value.absent(),
        reminderDevices: values.containsKey('reminder_devices')
            ? Value(values['reminder_devices']! as String)
            : const Value.absent(),
        projectId:
            values.containsKey('project_id') ? Value(values['project_id'] as String?) : const Value.absent(),
        trainingPlanId: values.containsKey('training_plan_id')
            ? Value(values['training_plan_id'] as String?)
            : const Value.absent(),
        updatedHlc: Value(hlc.pack()),
        updatedBy: Value(_recorder.deviceId),
      ),
    );
  }

  Future<CalendarEventRow?> _findActive(String id) {
    final query = _db.select(_db.calendarEvents)
      ..where((event) => event.id.equals(id) & event.deletedHlc.isNull());
    return query.getSingleOrNull();
  }

  static Map<String, Object?> _columnsOf(EventDraft draft, {required List<String> exdates}) {
    final title = draft.title.trim();
    if (title.isEmpty) {
      throw ArgumentError('Ein Termin braucht einen Titel.');
    }
    final recurrence = draft.recurrence;
    return {
      'title': title,
      'description': _blankToNull(draft.description),
      'location': _blankToNull(draft.location),
      'all_day': draft.allDay,
      'start_at': draft.storedStart.millisecondsSinceEpoch,
      'end_at': draft.storedEnd.millisecondsSinceEpoch,
      'recurrence': recurrence == null ? null : jsonEncode(recurrence.toJson()),
      'exdates': jsonEncode(recurrence == null ? const <String>[] : exdates),
      'tag_ids': jsonEncode(draft.tagIds),
      'reminder_minutes': draft.reminderMinutes,
      'reminder_devices': jsonEncode(
        draft.reminderDevices.isEmpty ? const [allDevices] : draft.reminderDevices,
      ),
      'project_id': draft.projectId,
      'training_plan_id': draft.trainingPlanId,
    };
  }

  static Map<String, Object?> _columnsOfRow(CalendarEventRow row) => {
        'title': row.title,
        'description': row.description,
        'location': row.location,
        'all_day': row.allDay,
        'start_at': row.startAt,
        'end_at': row.endAt,
        'recurrence': row.recurrence,
        'exdates': row.exdates,
        'tag_ids': row.tagIds,
        'reminder_minutes': row.reminderMinutes,
        'reminder_devices': row.reminderDevices,
        'project_id': row.projectId,
        'training_plan_id': row.trainingPlanId,
      };

  static String? _blankToNull(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _decodeList(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return [for (final item in decoded) if (item is String) item];
    } on FormatException {
      // Kaputte Daten nicht weiterreichen.
    }
    return const [];
  }

  static CalendarEvent _toEvent(CalendarEventRow row) {
    Recurrence? recurrence;
    final rule = row.recurrence;
    if (rule != null && rule.isNotEmpty) {
      try {
        recurrence = Recurrence.fromJson(jsonDecode(rule));
      } on FormatException {
        recurrence = null;
      }
    }
    final devices = _decodeList(row.reminderDevices);
    return CalendarEvent(
      id: row.id,
      title: row.title,
      description: row.description,
      location: row.location,
      allDay: row.allDay,
      start: DateTime.fromMillisecondsSinceEpoch(row.startAt, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(row.endAt, isUtc: true),
      recurrence: recurrence,
      exdates: _decodeList(row.exdates).toSet(),
      tagIds: _decodeList(row.tagIds),
      reminderMinutes: row.reminderMinutes,
      reminderDevices: devices.isEmpty ? const [allDevices] : devices,
      projectId: row.projectId,
      trainingPlanId: row.trainingPlanId,
    );
  }
}
