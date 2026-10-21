import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../network/care_api.dart' show ApiError;

typedef SyncSend = Future<dynamic> Function(String method, String path,
    [Map<String, dynamic>? body]);

String newOperationId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

bool connectionFailure(Object e) =>
    e is TimeoutException ||
    e is http.ClientException ||
    (e is ApiError && (e.status >= 500 || e.status == 429));

/// One encrypted, atomic storage value holds both the snapshot and the outbox.
/// Network acknowledgments remove operations only after durable local storage.
class OfflineCare extends ChangeNotifier {
  OfflineCare({required this.send, required this.read, required this.write});
  final SyncSend send;
  final Future<String?> Function() read;
  final Future<void> Function(String value) write;
  String? _session;
  final Map<String, dynamic> _parked = {};
  Map<String, dynamic>? _snapshot;
  final List<Map<String, dynamic>> _operations = [];
  Future<void> _serial = Future.value();
  bool offline = false;
  int get pendingCount => _operations.length;
  List<Map<String, dynamic>> get operations =>
      _operations.map((v) => Map<String, dynamic>.from(v)).toList();
  Map<String, dynamic>? get snapshot =>
      _snapshot == null ? null : project(_snapshot!);

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _serial.then((_) => action());
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> restore(String? session) => _locked(() async {
        if (_session == session && _session != null) return;
        final raw = await read();
        final saved = raw == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _parked
            .addAll(Map<String, dynamic>.from(saved['parked'] as Map? ?? {}));
        if (saved['session'] != session &&
            saved['snapshot'] is Map &&
            (saved['operations'] as List? ?? []).isNotEmpty) {
          final owner = (saved['snapshot'] as Map)['accountId'];
          if (owner is String) {
            _parked[owner] = {
              'snapshot': saved['snapshot'],
              'operations': saved['operations']
            };
          }
        }
        _session = session;
        _snapshot = null;
        _operations.clear();
        if (session != null && saved['session'] == session) {
          if (saved['snapshot'] is Map) {
            _snapshot = Map<String, dynamic>.from(saved['snapshot'] as Map);
          }
          _operations.addAll((saved['operations'] as List? ?? [])
              .map((v) => Map<String, dynamic>.from(v as Map)));
        }
        if (saved['session'] != session) {
          await _save();
        } else {
          notifyListeners();
        }
      });
  Future<void> _save() async {
    await write(jsonEncode({
      'parked': _parked,
      'session': _session,
      'snapshot': _snapshot,
      'operations': _operations
    }));
    notifyListeners();
  }

  Future<void> clear({bool preservePending = false}) => _locked(() async {
        if (preservePending &&
            _operations.isNotEmpty &&
            _snapshot?['accountId'] is String) {
          _parked[_snapshot!['accountId'] as String] = {
            'snapshot': _snapshot,
            'operations': List.of(_operations)
          };
        }
        _session = null;
        _snapshot = null;
        _operations.clear();
        offline = false;
        await _save();
      });
  Future<void> remember(Map<String, dynamic> remote) => _locked(() async {
        final saved = _parked.remove(remote['accountId']);
        if (saved is Map && _operations.isEmpty) {
          _operations.addAll((saved['operations'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map)));
          for (final op in _operations) {
            if (const {'REQUEST_FAILED', 'UNAUTHORIZED', 'ACCESS_EXPIRED'}
                .contains(op['error'])) {
              op.remove('error');
            }
          }
        }
        final subjects = (remote['pets'] as List? ?? []).cast<Map>();
        final allowed = subjects
            .where((s) => s['canCareSubject'] != false)
            .map((s) => s['id'])
            .toSet();
        _operations.removeWhere((op) =>
            op['subjectType'] == 'HUMAN' && !allowed.contains(op['subjectId']));
        // A session may move to another household. Never project old household data.
        _snapshot = jsonDecode(jsonEncode(remote)) as Map<String, dynamic>;
        for (final op in _operations) {
          if (op['error'] == 'ACCESS_EXPIRED') op.remove('error');
          if ((op['body'] as Map)['householdId'] != remote['householdId']) {
            op['error'] = 'HOUSEHOLD_CHANGED';
          }
        }
        offline = false;
        await _save();
      });
  Map<String, dynamic> project(Map<String, dynamic> source) {
    final result = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    final blocked = _operations
        .where((op) => op['error'] != null)
        .map((op) => (op['body'] as Map)['taskId'])
        .toSet();
    for (final op in _operations) {
      final body = op['body'] as Map;
      if (body['householdId'] != result['householdId'] ||
          blocked.contains(body['taskId'])) {
        continue;
      }
      for (final key in ['tasks', 'reminderTasks']) {
        final rows = (result[key] as List? ?? []).cast<Map>();
        for (final task in rows.where((task) => task['id'] == body['taskId'])) {
          switch (body['action']) {
            case 'COMPLETE':
              task['completed'] = true;
            case 'REOPEN':
              task['completed'] = false;
            case 'RESCHEDULE':
              task['dueAt'] = body['dueAt'];
            case 'ASSIGN':
              task['assignedTo'] = body['memberId'];
            case 'SKIP':
              task['skipped'] = true;
            case 'CANCEL':
              task['cancelled'] = true;
            case 'EDIT':
              task['title'] = body['title'];
              if (body['careType'] != null) task['careType'] = body['careType'];
          }
          task['pendingSync'] = true;
        }
      }
    }
    return result;
  }

  Future<void> enqueue(Map<String, dynamic> task, String action,
          [Map<String, dynamic> fields = const {}]) =>
      _locked(() async {
        if (_session == null ||
            _snapshot?['householdId'] == null ||
            task['revision'] == null) {
          throw const ApiError(409, 'SYNC_REFRESH_REQUIRED');
        }
        if (_operations.length >= 200) {
          throw const ApiError(409, 'SYNC_QUEUE_FULL');
        }
        final previous = _operations
            .where((v) => (v['body'] as Map)['taskId'] == task['id'])
            .lastOrNull;
        final body = <String, dynamic>{
          'operationId': newOperationId(),
          'householdId': _snapshot!['householdId'],
          'taskId': task['id'],
          'revision': task['revision'],
          'action': action,
          if (previous != null)
            'dependsOn': (previous['body'] as Map)['operationId'],
          ...fields,
        };
        final op = <String, dynamic>{
          'body': body,
          'title': task['title'],
          'subjectId': task['petId'],
          'subjectType': (_snapshot?['pets'] as List? ?? [])
                  .cast<Map>()
                  .where((s) => s['id'] == task['petId'])
                  .firstOrNull?['subjectType'] ??
              'PET',
          'createdAt': DateTime.now().toUtc().toIso8601String()
        };
        final rows = (_snapshot!['tasks'] as List? ?? []).toList();
        if (!rows.any((v) => (v as Map)['id'] == task['id'])) {
          rows.add(task);
          _snapshot!['tasks'] = rows;
        }
        _operations.add(op);
        try {
          await _save();
        } catch (_) {
          _operations.remove(op);
          rethrow;
        }
      });
  Future<void> flush() => _locked(() async {
        final blocked = <String>{};
        for (final op in List.of(_operations)) {
          final body = Map<String, dynamic>.from(op['body'] as Map);
          final taskId = body['taskId'] as String;
          if (op['error'] != null || blocked.contains(taskId)) {
            blocked.add(taskId);
            continue;
          }
          try {
            final result = Map<String, dynamic>.from(
                await send('POST', '/care/sync', body) as Map);
            // Persist server acknowledgment and updated base snapshot together.
            if (_snapshot != null) {
              final task = result['task'] as Map;
              for (final key in ['tasks', 'reminderTasks']) {
                final list = (_snapshot![key] as List? ?? []).toList();
                list.removeWhere((v) => (v as Map)['id'] == taskId);
                list.add(task);
                _snapshot![key] = list;
              }
              if (result['reminderTasks'] is List) {
                _snapshot!['reminderTasks'] = result['reminderTasks'];
              }
              final incoming = result['events'] as List? ?? [];
              final ids = incoming.map((v) => (v as Map)['id']).toSet();
              _snapshot!['history'] = [
                ...incoming,
                ...(_snapshot!['history'] as List? ?? [])
                    .where((v) => !ids.contains((v as Map)['id']))
              ];
            }
            _operations.remove(op);
            try {
              await _save();
            } catch (_) {
              _operations.insert(0, op);
              rethrow;
            }
            offline = false;
          } catch (e) {
            if (connectionFailure(e)) {
              offline = true;
              notifyListeners();
              break;
            }
            if (e is ApiError) {
              op['error'] = e.code;
              blocked.add(taskId);
              await _save();
              if (e.status == 401 || e.code == 'ACCESS_EXPIRED') rethrow;
            } else {
              rethrow;
            }
          }
        }
        notifyListeners();
      });

  /// Discard the task's whole dependent chain, never just its parent operation.
  Future<void> discard(String taskId) => _locked(() async {
        _operations
            .removeWhere((op) => (op['body'] as Map)['taskId'] == taskId);
        await _save();
      });
}
