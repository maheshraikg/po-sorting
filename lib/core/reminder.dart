/// Optional daily practice reminder ("5-minute PIN quiz"), a local
/// notification scheduled on the phone; nothing goes online.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const int _reminderId = 7001;

class PracticeReminder {
  PracticeReminder._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // The app is for India; reminders use IST.
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')));
    _ready = true;
  }

  /// Next [minutes] past midnight (IST) from [now].
  static tz.TZDateTime nextAt(int minutes, tz.TZDateTime now) {
    var t = tz.TZDateTime(now.location, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Asks for notification permission (Android 13+) and schedules the
  /// reminder every day at [minutes] past midnight. False if not allowed.
  static Future<bool> enable(int minutes, {required String title, required String body, required String channel}) async {
    if (!supported) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission() ?? true;
    if (!ok) return false;
    await _plugin.cancel(id: _reminderId);
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: title,
      body: body,
      scheduledDate: nextAt(minutes, tz.TZDateTime.now(tz.local)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails('practice', channel, importance: Importance.defaultImportance, priority: Priority.defaultPriority),
      ),
      // Inexact: no exact-alarm permission needed; a few minutes late is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  static Future<void> disable() async {
    if (!supported) return;
    await _init();
    await _plugin.cancel(id: _reminderId);
  }
}
