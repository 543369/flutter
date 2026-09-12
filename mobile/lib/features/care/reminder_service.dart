import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

List<Map<String, dynamic>> upcomingReminders(
    List<Map<String, dynamic>> tasks, DateTime now) {
  final upcoming = tasks
      .where((task) =>
          task['completed'] != true &&
          task['cancelled'] != true &&
          DateTime.parse(task['dueAt'] as String).isAfter(now))
      .toList();
  upcoming.sort((a, b) {
    final time = DateTime.parse(a['dueAt'] as String)
        .compareTo(DateTime.parse(b['dueAt'] as String));
    return time == 0 ? (a['id'] as String).compareTo(b['id'] as String) : time;
  });
  return upcoming.take(60).toList();
}

class ReminderService {
  final plugin = FlutterLocalNotificationsPlugin();
  final storage = const FlutterSecureStorage();
  bool enabled = false;
  bool ready = false;
  String? _signature;

  Future<String> deviceZone() => FlutterTimezone.getLocalTimezone();
  Future<void> initialize(VoidCallback onTap) async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_paw'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false),
          macOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (_) => onTap());
    enabled = await storage.read(key: 'care_reminders') == 'true';
    ready = true;
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) onTap();
  }

  Future<bool> allowed() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (await plugin
                  .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin>()
                  ?.checkPermissions())
              ?.isEnabled ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return (await plugin
                  .resolvePlatformSpecificImplementation<
                      MacOSFlutterLocalNotificationsPlugin>()
                  ?.checkPermissions())
              ?.isEnabled ??
          false;
    }
    return false;
  }

  Future<bool> setEnabled(bool value) async {
    if (!ready) throw StateError('Notifications not initialized');
    bool granted = false;
    if (value && defaultTargetPlatform == TargetPlatform.iOS) {
      granted = await plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (value && defaultTargetPlatform == TargetPlatform.android) {
      granted = await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } else if (value && defaultTargetPlatform == TargetPlatform.macOS) {
      granted = await plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    enabled = value && granted;
    await storage.write(key: 'care_reminders', value: enabled.toString());
    _signature = null;
    if (!enabled) await plugin.cancelAll();
    return enabled;
  }

  Future<void> sync(List<Map<String, dynamic>> tasks,
      {required bool chinese}) async {
    if (!ready) throw StateError('Notifications not initialized');
    if (enabled && !await allowed()) {
      enabled = false;
      await storage.write(key: 'care_reminders', value: 'false');
    }
    final selected = enabled
        ? upcomingReminders(tasks, DateTime.now())
        : <Map<String, dynamic>>[];
    final signature = jsonEncode([chinese, selected]);
    if (_signature == signature) return;
    await plugin.cancelAll();
    for (var i = 0; i < selected.length; i++) {
      final task = selected[i];
      await plugin.zonedSchedule(
        i + 1,
        chinese ? '照护时间到了' : 'Time for pet care',
        "${task['petName']} · ${task['title']}",
        tz.TZDateTime.from(DateTime.parse(task['dueAt'] as String), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails('petcare_care', 'Pet care',
              channelDescription: 'Scheduled pet care reminders',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_paw'),
          iOS:
              DarwinNotificationDetails(presentAlert: true, presentSound: true),
          macOS:
              DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task['id'] as String,
      );
    }
    _signature = signature;
  }
}
