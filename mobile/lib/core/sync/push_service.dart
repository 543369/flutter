import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/care_api.dart';
import '../../features/care/reminder_service.dart';
import 'offline_care.dart';

/// Public Firebase app configuration only. APNs keys and service-account JSON
/// belong in Firebase/the server, never in these build definitions.
class PushConfig {
  static const enabled =
      bool.fromEnvironment('PUSH_ENABLED', defaultValue: false);
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static FirebaseOptions get options => FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId:
            const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      );
  static Future<void> initialize() async {
    if (!enabled || !supported) return;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    FirebaseMessaging.onBackgroundMessage(carePushBackground);
  }
}

@pragma('vm:entry-point')
Future<void> carePushBackground(RemoteMessage message) async {
  if (!PushConfig.enabled || message.data['type'] != 'CARE_CHANGED') return;
  final api = CareApi();
  String? messageSession;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: PushConfig.options);
    }
    await api.restore();
    final session = api.token;
    messageSession = session;
    if (session == null) return;
    // Background isolate never flushes or writes the foreground outbox/cache.
    // The push is only an invalidation; always read authorized current state.
    final remote = Map<String, dynamic>.from(
        await api.request('GET', '/dashboard?compact=true') as Map);
    if (remote['householdId'] != message.data['householdId']) return;
    if (await api.storage.read(key: 'session') != session) return;
    final snapshot = api.offlineCare.project(remote);
    final reminders = ReminderService();
    await reminders.initialize((_) {});
    await reminders.sync(
        (snapshot['reminderTasks'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList(),
        chinese: PlatformDispatcher.instance.locale.languageCode == 'zh');
  } on ApiError catch (e) {
    if ((e.status == 401 || e.code == 'ACCESS_EXPIRED') &&
        messageSession != null &&
        await api.storage.read(key: 'session') == messageSession) {
      // A revoked device may still get a queued message. Remove its reminders,
      // but do not erase a newer session or the foreground operation journal.
      try {
        final reminders = ReminderService();
        await reminders.initialize((_) {});
        await reminders.sync([], chinese: false);
      } catch (_) {/* Foreground resume retries local cleanup. */}
    }
  } catch (_) {
    /* Retry on the next push or app resume; preserve local alarms. */
  }
}

class PushService {
  PushService(this.api, this.onChanged);
  final CareApi api;
  final Future<void> Function() onChanged;
  StreamSubscription<RemoteMessage>? _messages;
  StreamSubscription<String>? _tokens;
  String? _registeredSession;
  bool _registering = false;
  Future<void> start() async {
    if (!PushConfig.enabled || !PushConfig.supported) return;
    await PushConfig.initialize();
    _messages ??= FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'CARE_CHANGED') unawaited(onChanged());
    });
    _tokens ??= FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      _registeredSession = null;
      unawaited(register().catchError((Object _) {}));
    });
    await register();
  }

  Future<void> register() async {
    if (!PushConfig.enabled ||
        !PushConfig.supported ||
        _registering ||
        api.token == null ||
        _registeredSession == api.token) {
      return;
    }
    _registering = true;
    final session = api.token;
    try {
      final status = await api.request('GET', '/push/status');
      if (status['enabled'] != true) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || session != api.token) return;
      var installation = await api.storage.read(key: 'push_installation_id');
      if (installation == null) {
        installation = newOperationId();
        await api.storage
            .write(key: 'push_installation_id', value: installation);
      }
      await api.request('PUT', '/push/devices',
          {'installationId': installation, 'token': token});
      _registeredSession = session;
    } finally {
      _registering = false;
    }
  }

  void dispose() {
    _messages?.cancel();
    _tokens?.cancel();
  }
}
