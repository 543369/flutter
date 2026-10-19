import 'dart:convert';
import '../sync/offline_care.dart';
import '../images/photo_cache.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CareApi {
  final FlutterSecureStorage storage = const FlutterSecureStorage(
    // Ad-hoc signed macOS debug builds use the login keychain.
    // Production retains the data-protection keychain and requires signing capabilities.
    mOptions: MacOsOptions(useDataProtectionKeyChain: kReleaseMode),
  );
  late final OfflineCare offlineCare = OfflineCare(
    send: request,
    read: () => storage.read(key: 'offline_care_v1'),
    write: (value) => storage.write(key: 'offline_care_v1', value: value),
  );
  String? token;
  String? _photoSession;
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://127.0.0.1:18080');

  Future<void> restore() async {
    token = await storage.read(key: 'session');
    await offlineCare.restore(token);
  }

  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.base.resolve('$baseUrl/api$path');
    if (kReleaseMode && uri.scheme != 'https') {
      throw const ApiError(0, 'HTTPS_REQUIRED');
    }
    final client = http.Client();
    try {
      final req = http.Request(method, uri);
      req.headers['X-Device-Name'] =
          kIsWeb ? 'Web Browser' : '${defaultTargetPlatform.name} App';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final response =
          await client.send(req).timeout(const Duration(seconds: 15));
      final text = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        var code = 'REQUEST_FAILED';
        try {
          final body = jsonDecode(text);
          if (body is Map && body['error'] is String) {
            code = body['error'] as String;
          }
        } on FormatException {
          /* An upstream proxy may return non-JSON errors. */
        }
        throw ApiError(response.statusCode, code);
      }
      return text.isEmpty ? null : jsonDecode(text);
    } finally {
      client.close();
    }
  }

  Future<void> saveSession(String value) async {
    if (offlineCare.pendingCount > 0 && token != value) {
      throw const ApiError(409, 'SYNC_PENDING');
    }
    await storage.write(key: 'session', value: value);
    token = value;
    await offlineCare.restore(token);
  }

  Future<void> clearSession({bool preservePending = false}) async {
    await offlineCare.clear(preservePending: preservePending);
    await storage.delete(key: 'session');
    token = null;
    _petPhotos.clear();
    PhotoCache.shared.clear();
  }

  Future<void> register(String email, String password, String name) async {
    final result = await request('POST', '/auth/register', {
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      'locale': PlatformDispatcher.instance.locale.toLanguageTag()
    });
    await saveSession(result['token'] as String);
  }

  Future<void> registerVerified(
      String email, String password, String name, String code) async {
    final result = await request('POST', '/auth/register', {
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
      'code': code.trim(),
    });
    await saveSession(result['token'] as String);
  }

  Future<void> login(String email, String password) async {
    final result = await request(
        'POST', '/auth/login', {'email': email.trim(), 'password': password});
    await saveSession(result['token'] as String);
  }

  Future<void> logout() async {
    if (offlineCare.pendingCount > 0) throw const ApiError(409, 'SYNC_PENDING');
    try {
      await request('POST', '/auth/logout');
    } on ApiError catch (e) {
      if (e.status != 401) rethrow;
    }
    await clearSession();
  }

  // Kept for migrating and testing existing device identities; not offered in new-user UI.
  Future<void> createSession() async {
    final result = await request('POST', '/session');
    await saveSession(result['token'] as String);
  }

  /// Writes are persisted before sending. Older servers remain online-only.
  Future<Map<String, dynamic>> writeCareTask(
      Map<String, dynamic> task,
      String action,
      String method,
      String path,
      Map<String, dynamic> body) async {
    if (task['revision'] == null) {
      return Map<String, dynamic>.from(
          await request(method, path, body) as Map);
    }
    await offlineCare.restore(token);
    await offlineCare.enqueue(task, action, {
      if (body.containsKey('dueAt')) 'dueAt': body['dueAt'],
      if (body.containsKey('memberId')) 'memberId': body['memberId'],
      if (body.containsKey('title')) 'title': body['title'],
      if (body.containsKey('careType')) 'careType': body['careType'],
    });
    if (!offlineCare.offline) await offlineCare.flush();
    final failed = offlineCare.operations
        .where((op) =>
            (op['body'] as Map)['taskId'] == task['id'] && op['error'] != null)
        .firstOrNull;
    if (failed != null) throw ApiError(409, failed['error'] as String);
    final snapshot = offlineCare.snapshot!;
    final updated = (snapshot['tasks'] as List)
        .cast<Map>()
        .where((v) => v['id'] == task['id'])
        .first;
    final events = (snapshot['history'] as List? ?? [])
        .cast<Map>()
        .where((v) => v['taskId'] == task['id'])
        .toList();
    return {
      ...updated,
      'task': updated,
      'events': events,
      'reminderTasks': snapshot['reminderTasks'],
      if (events.isNotEmpty && updated['pendingSync'] != true)
        'lastEvent': events.first
    };
  }

  final _petPhotos = <String, Map<String, dynamic>>{};
  Future<Map<String, dynamic>> dashboard() async {
    if (_photoSession != token) {
      _photoSession = token;
      _petPhotos.clear();
      PhotoCache.shared.clear();
    }
    await offlineCare.restore(token);
    Map<String, dynamic> result;
    try {
      await offlineCare.flush();
      result = Map<String, dynamic>.from(
          await request('GET', '/dashboard?compact=true') as Map);
      await offlineCare.remember(result);
      result = offlineCare.project(result);
    } catch (e) {
      if (connectionFailure(e) && offlineCare.snapshot != null) {
        offlineCare.offline = true;
        return offlineCare.snapshot!;
      }
      rethrow;
    }
    final pets = (result['pets'] as List)
        .map((pet) => Map<String, dynamic>.from(pet as Map))
        .toList();
    result['pets'] = pets;
    final ids = pets.map((p) => p['id']).toSet();
    _petPhotos.removeWhere((key, _) => !ids.contains(key));
    for (final pet in pets) {
      final id = pet['id'] as String;
      final cached = _petPhotos[id];
      if (cached != null && cached['version'] == pet['photoRevision']) {
        pet['photoData'] = cached['photoData'];
        pet['photos'] = cached['photos'];
      } else {
        pet['photosPending'] = true;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> loadPetPhotos(Map<String, dynamic> pet) async {
    final session = token;
    final id = pet['id'] as String;
    final photos = Map<String, dynamic>.from(
        await request('GET', '/pets/$id/photos') as Map);
    if (session == token && _photoSession == session) {
      _petPhotos[id] = {...photos, 'version': pet['photoRevision']};
    }
    return photos;
  }

  Future<void> deleteAccount() async {
    await request('DELETE', '/account');
    await clearSession();
  }
}

class ApiError implements Exception {
  final int status;
  final String code;
  const ApiError(this.status, this.code);
}
