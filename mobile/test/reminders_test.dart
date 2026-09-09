import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/reminders.dart';

Map<String, dynamic> task(String id, DateTime due,
        {bool done = false, bool cancelled = false}) =>
    {
      'id': id,
      'dueAt': due.toUtc().toIso8601String(),
      'completed': done,
      'cancelled': cancelled,
      'title': 'Meal',
      'petName': 'Mochi',
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'selects nearest 60 future tasks and excludes completed, cancelled and past care',
      () {
    final now = DateTime.utc(2026, 9, 7);
    final items = [
      for (var i = 70; i > 0; i--) task('$i', now.add(Duration(minutes: i))),
      task('done', now.add(const Duration(seconds: 1)), done: true),
      task('cancel', now.add(const Duration(seconds: 2)), cancelled: true),
      task('past', now.subtract(const Duration(seconds: 1)))
    ];
    final selected = upcomingReminders(items, now);
    expect(selected.length, 60);
    expect(selected.first['id'], '1');
    expect(selected.last['id'], '60');
    expect(items.first['id'], '70');
  });
  test(
      'native schedules cancel after completion and identical sync does not reschedule',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    const storage =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') return true;
      if (call.method == 'areNotificationsEnabled') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
        storage, (call) async => call.method == 'read' ? 'true' : null);
    try {
      final service = ReminderService();
      await service.initialize(() {});
      final due = DateTime.now().add(const Duration(hours: 1));
      final items = [task('1', due)];
      await service.sync(items, chinese: false);
      expect(calls.where((c) => c.method == 'zonedSchedule').length, 1);
      await service.sync(items, chinese: false);
      expect(calls.where((c) => c.method == 'zonedSchedule').length, 1);
      await service.sync([task('1', due, done: true)], chinese: false);
      expect(calls.where((c) => c.method == 'cancelAll').length, 2);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(storage, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
