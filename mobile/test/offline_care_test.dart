import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/core/sync/offline_care.dart';

void main() {
  Map<String, dynamic> task() => {
        'id': 'task',
        'petId': 'pet',
        'title': 'Meal',
        'revision': 0,
        'completed': false,
        'dueAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String()
      };
  Map<String, dynamic> dashboard() => {
        'householdId': 'home',
        'accountId': 'account',
        'tasks': [task()],
        'reminderTasks': [task()],
        'history': [],
        'pets': []
      };
  test('completion survives restart and replays with stable operation IDs',
      () async {
    String? disk;
    bool online = false;
    final sent = <Map<String, dynamic>>[];
    Future<dynamic> send(String method, String path,
        [Map<String, dynamic>? body]) async {
      sent.add(Map.from(body!));
      if (!online) throw TimeoutException('offline');
      return {
        'task': {
          ...task(),
          'completed': body['action'] == 'COMPLETE',
          'revision': sent.length
        },
        'events': [],
        'reminderTasks': []
      };
    }

    OfflineCare store() => OfflineCare(
        send: send,
        read: () async => disk,
        write: (value) async {
          disk = value;
        });
    final first = store();
    await first.restore('session');
    await first.remember(dashboard());
    await first.enqueue(task(), 'COMPLETE');
    await first.flush();
    expect(first.pendingCount, 1);
    expect((first.snapshot!['tasks'] as List).single['completed'], true);
    final replay = store();
    await replay.restore('session');
    expect(replay.pendingCount, 1);
    await replay.enqueue(task(), 'REOPEN');
    expect((replay.operations.last['body'] as Map)['dependsOn'],
        sent.first['operationId']);
    online = true;
    await replay.flush();
    expect(replay.pendingCount, 0);
    expect(sent[1]['operationId'], sent.first['operationId']);
    expect((replay.snapshot!['tasks'] as List).single['completed'], false);
  });
  test('lost response retries same key and conflict pauses dependent chain',
      () async {
    String? disk;
    int calls = 0;
    final ids = <dynamic>[];
    final queue = OfflineCare(
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
        send: (method, path, [body]) async {
          calls++;
          ids.add(body!['operationId']);
          if (calls == 1) throw TimeoutException('ack lost');
          throw const ApiError(409, 'SYNC_CONFLICT');
        });
    await queue.restore('one');
    await queue.remember(dashboard());
    await queue.enqueue(task(), 'COMPLETE');
    await queue.flush();
    await queue.enqueue(task(), 'REOPEN');
    await queue.flush();
    expect(ids[0], ids[1]);
    expect(calls, 2);
    expect(queue.pendingCount, 2);
    expect(queue.operations.first['error'], 'SYNC_CONFLICT');
    await queue.flush();
    expect(calls, 2);
    await queue.discard('task');
    expect(queue.pendingCount, 0);
  });
  test('session and household changes cannot replay or project old changes',
      () async {
    String? disk;
    final queue = OfflineCare(
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
        send: (method, path, [body]) async =>
            throw StateError('must not send'));
    await queue.restore('one');
    await queue.remember(dashboard());
    await queue.enqueue(task(), 'COMPLETE');
    await queue.remember({...dashboard(), 'householdId': 'another'});
    expect(queue.operations.first['error'], 'HOUSEHOLD_CHANGED');
    expect((queue.snapshot!['tasks'] as List).single['completed'], false);
    await queue.flush();
    await queue.restore('two');
    expect(queue.pendingCount, 0);
    expect(queue.snapshot, isNull);
  });
  test('expired session keeps changes sealed until the same account signs in',
      () async {
    String? disk;
    OfflineCare store() => OfflineCare(
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
        send: (method, path, [body]) async =>
            throw StateError('must not send'));
    final first = store();
    await first.restore('old');
    await first.remember(dashboard());
    await first.enqueue(task(), 'COMPLETE');
    await first.clear(preservePending: true);
    final next = store();
    await next.restore('new');
    expect(next.snapshot, isNull);
    await next.remember({...dashboard(), 'accountId': 'another'});
    expect(next.pendingCount, 0);
    await next.restore('same-account-new-session');
    await next.remember(dashboard());
    expect(next.pendingCount, 1);
    expect((next.snapshot!['tasks'] as List).single['completed'], true);
  });
  test('storage failure cannot report a successful enqueue', () async {
    String? disk;
    bool fail = false;
    final queue = OfflineCare(
        read: () async => disk,
        write: (value) async {
          if (fail) throw StateError('disk unavailable');
          disk = value;
        },
        send: (method, path, [body]) async => null);
    await queue.restore('one');
    await queue.remember(dashboard());
    fail = true;
    await expectLater(queue.enqueue(task(), 'COMPLETE'), throwsStateError);
    expect(queue.pendingCount, 0);
  });

  test(
      'revoked human profile removes its pending operations and cached records',
      () async {
    String? disk;
    final store = OfflineCare(
        send: (_, __, [___]) async => throw TimeoutException('offline'),
        read: () async => disk,
        write: (v) async {
          disk = v;
        });
    await store.restore('session');
    await store.remember({
      ...dashboard(),
      'pets': [
        {'id': 'pet', 'subjectType': 'HUMAN', 'canCareSubject': true}
      ]
    });
    await store.enqueue(task(), 'COMPLETE');
    expect(store.pendingCount, 1);
    await store.remember(
        {...dashboard(), 'pets': [], 'tasks': [], 'reminderTasks': []});
    expect(store.pendingCount, 0);
    expect(store.snapshot!['tasks'], isEmpty);
    expect(disk, isNot(contains('Meal')));
  });
}
