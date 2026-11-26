import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';

/// Zeigt geplante Erinnerungen an. Android/iOS: vom Betriebssystem geplant;
/// Windows: von der laufenden App (siehe Spec, Abschnitt Ansätze).
abstract interface class ReminderSink {
  /// Ersetzt alle bisher geplanten Erinnerungen durch [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Fragt einmal nach der Erlaubnis, Benachrichtigungen zu zeigen.
  Future<void> requestPermission();

  Future<void> dispose();
}

/// Plant nach jeder Änderung an Terminen (auch per Sync) die Erinnerungen
/// dieses Geräts neu. Zusätzlich stündlich, damit das 30-Tage-Fenster
/// weiterwandert.
class ReminderService {
  ReminderService({
    required Stream<List<CalendarEvent>> events,
    required this.deviceId,
    required this.sink,
    DateTime Function()? clock,
  })  : _events = events,
        _clock = clock ?? DateTime.now;

  final Stream<List<CalendarEvent>> _events;
  final String deviceId;
  final ReminderSink sink;
  final DateTime Function() _clock;

  StreamSubscription<List<CalendarEvent>>? _subscription;
  Timer? _hourly;
  List<CalendarEvent> _latest = const [];
  String? _lastPlan;
  var _askedPermission = false;
  Future<void> _pending = Future<void>.value();

  void start() {
    _subscription = _events.listen((events) {
      _latest = events;
      _schedule();
    });
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => _schedule());
  }

  void _schedule() {
    // Nacheinander planen, nie zwei Durchläufe gleichzeitig.
    _pending = _pending.then((_) => _plan()).catchError((Object error, StackTrace stack) {
      debugPrint('Erinnerungen konnten nicht geplant werden: $error\n$stack');
    });
  }

  Future<void> _plan() async {
    final reminders = planReminders(events: _latest, deviceId: deviceId, now: _clock());
    final fingerprint = [
      for (final r in reminders) '${r.notificationId}@${r.fireAt.millisecondsSinceEpoch}:${r.title}:${r.body}',
    ].join('|');
    if (fingerprint == _lastPlan) return;
    if (reminders.isNotEmpty && !_askedPermission) {
      _askedPermission = true;
      await sink.requestPermission();
    }
    await sink.replaceAll(reminders);
    _lastPlan = fingerprint;
  }

  Future<void> dispose() async {
    _hourly?.cancel();
    await _subscription?.cancel();
    await sink.dispose();
  }
}
