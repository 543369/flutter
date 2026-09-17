import 'dart:convert';
import '../images/photo_cache.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CareApi {
  final FlutterSecureStorage storage = const FlutterSecureStorage(
    // Ad-hoc signed macOS debug builds use the login keychain.
    // Production retains the data-protection keychain and requires signing capabilities.
    mOptions: MacOsOptions(useDataProtectionKeyChain: kReleaseMode),
  );
  String? token;
  String? _photoSession;
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://127.0.0.1:18080');

  Future<void> restore() async {
    token = await storage.read(key: 'session');
  }

  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl/api$path');
    if (kReleaseMode && uri.scheme != 'https') {
      throw const ApiError(0, 'HTTPS_REQUIRED');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      req.headers.set('X-Device-Name', '${Platform.operatingSystem} App');
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final response = await req.close().timeout(const Duration(seconds: 15));
      final text = await response
          .transform(utf8.decoder)
          .join()
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
      client.close(force: true);
    }
  }

  Future<void> saveSession(String value) async {
    await storage.write(key: 'session', value: value);
    token = value;
  }

  Future<void> clearSession() async {
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
      'locale': Platform.localeName.replaceAll('_', '-')
    });
    await saveSession(result['token'] as String);
  }

  Future<void> login(String email, String password) async {
    final result = await request(
        'POST', '/auth/login', {'email': email.trim(), 'password': password});
    await saveSession(result['token'] as String);
  }

  Future<void> logout() async {
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

  final _petPhotos = <String, Map<String, dynamic>>{};
  Future<Map<String, dynamic>> dashboard() async {
    if (_photoSession != token) {
      _photoSession = token;
      _petPhotos.clear();
      PhotoCache.shared.clear();
    }
    final result = Map<String, dynamic>.from(
        await request('GET', '/dashboard?compact=true') as Map);
    final pets = (result['pets'] as List)
        .map((pet) => Map<String, dynamic>.from(pet as Map))
        .toList();
    result['pets'] = pets;
    final ids = pets.map((p) => p['id']).toSet();
    _petPhotos.removeWhere((key, _) => !ids.contains(key));
    for (final pet in pets) {
      final id = pet['id'] as String;
      final cached = _petPhotos[id];
      if (cached == null || cached['version'] != pet['photoRevision']) {
        final photos = Map<String, dynamic>.from(
            await request('GET', '/pets/$id/photos') as Map);
        _petPhotos[id] = {...photos, 'version': pet['photoRevision']};
      }
      pet['photoData'] = _petPhotos[id]!['photoData'];
      pet['photos'] = _petPhotos[id]!['photos'];
    }
    return result;
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
