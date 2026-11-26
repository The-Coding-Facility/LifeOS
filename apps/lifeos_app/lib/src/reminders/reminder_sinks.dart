import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lifeos_calendar/lifeos_calendar.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

const _channelId = 'lifeos_termine';
const _channelName = 'Termine';
const _windowsAppId = 'de.lifeos.LifeOS';
const _windowsGuid = '5b1f4e8a-7c2d-4e91-9a36-0d8c41f2b7e5';

// Nicht const: Nicht jede Plattform-Klasse hat einen const-Konstruktor.
final _details = NotificationDetails(
  android: const AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Erinnerungen an Termine aus dem Kalender',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: const DarwinNotificationDetails(),
  windows: WindowsNotificationDetails(),
);

/// Richtet das Benachrichtigungs-Plugin ein und liefert die passende
/// Umsetzung für diese Plattform. `null`, wenn die Plattform keine
/// Benachrichtigungen unterstützt.
Future<ReminderSink?> createReminderSink() async {
  if (!(Platform.isAndroid || Platform.isIOS || Platform.isWindows)) return null;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      windows: WindowsInitializationSettings(
        appName: 'LifeOS',
        appUserModelId: _windowsAppId,
        guid: _windowsGuid,
      ),
    ),
  );
  if (Platform.isWindows) return InAppReminderSink(plugin);
  tz_data.initializeTimeZones();
  return PluginReminderSink(plugin);
}

/// Android und iOS: Das Betriebssystem zeigt die Erinnerung, auch wenn die
/// App geschlossen ist.
class PluginReminderSink implements ReminderSink {
  PluginReminderSink(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAll();
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.eventId,
      );
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Windows: Ohne MSIX-Paket kann Windows geplante Meldungen nicht
/// zuverlässig zurücknehmen. Deshalb zeigt die laufende App sie selbst an.
class InAppReminderSink implements ReminderSink {
  InAppReminderSink(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final _timers = <Timer>[];

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    final now = DateTime.now().toUtc();
    for (final reminder in reminders) {
      final delay = reminder.fireAt.difference(now);
      if (delay.isNegative) continue;
      _timers.add(Timer(delay, () {
        _plugin.show(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.body,
          notificationDetails: _details,
          payload: reminder.eventId,
        );
      }));
    }
  }

  @override
  Future<void> dispose() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
