import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'overdue_care_page_test.dart' show OverdueApi, openPage;

class ManagementApi extends OverdueApi {
  bool failGroups = false, failHistory = false, oversized = false;
  Map<String, dynamic>? retryBody;
  final states = <String, String>{
    'older': 'RUNNING',
    'newer': 'RUNNING',
    'complete': 'COMPLETE'
  };
  final statuses = <String, String>{
    'older': 'PENDING',
    'newer': 'PENDING',
    'complete': 'FAILED'
  };
  Map<String, dynamic> batch(String id) => {
        'id': id,
        'state': states[id],
        'finished': states[id] != 'RUNNING',
        'createdAt': at,
        'total': 1,
        'remaining': statuses[id] == 'PENDING' ? 1 : 0,
        'success': statuses[id] == 'SUCCESS' ? 1 : 0,
        'changed': 0,
        'failed': statuses[id] == 'FAILED' ? 1 : 0,
        'stopped': statuses[id] == 'STOPPED' ? 1 : 0,
      };
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse(path);
    if (uri.path == '/care/overdue/groups') {
      if (failGroups) {
        failGroups = false;
        throw TimeoutException('offline');
      }
      final result = Map<String, dynamic>.from(
          await super.request(method, path, body) as Map);
      if (oversized) {
        result['total'] = 6003;
        result['recurringTotal'] = 6001;
        (result['items'] as List).first['count'] = 5986;
      }
      return result;
    }
    if (uri.path == '/care/overdue/batches') {
      if (failHistory) {
        failHistory = false;
        throw TimeoutException('history unavailable');
      }
      return {
        'items': [
          for (final id in states.keys)
            if (uri.queryParameters['unfinished'] != 'true' ||
                states[id] == 'RUNNING')
              batch(id)
        ],
        'hasMore': false,
        'nextCursor': ''
      };
    }
    final parts = uri.path.split('/');
    if (parts.length == 6 &&
        parts[3] == 'batches' &&
        states.containsKey(parts[4])) {
      final id = parts[4];
      switch (parts[5]) {
        case 'items':
          final row = {
            'id': 'item-$id',
            'title': 'Saved reminder $id',
            'dueAt': at,
            'status': statuses[id],
            'reason': statuses[id] == 'FAILED'
                ? 'INTEGRITY_ERROR'
                : statuses[id] == 'STOPPED'
                    ? 'USER_ENDED'
                    : null,
            'attempts': 1
          };
          final filter = uri.queryParameters['status'];
          return {
            'batch': batch(id),
            'items': filter == null || filter.isEmpty || filter == statuses[id]
                ? [row]
                : [],
            'hasMore': false,
            'nextCursor': ''
          };
        case 'retry':
          retryBody = body;
          statuses[id] = 'PENDING';
          states[id] = 'RUNNING';
          return batch(id);
        case 'apply':
          statuses[id] = 'SUCCESS';
          states[id] = 'COMPLETE';
          return batch(id);
        case 'end':
          statuses[id] = 'STOPPED';
          states[id] = 'ENDED';
          return batch(id);
      }
    }
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets(
      'oversize selection is explained before preview and blocks submit',
      (tester) async {
    final api = ManagementApi()..oversized = true;
    await openPage(tester, api);
    await tester.tap(find.text('Select recurring only'));
    await tester.pumpAndSettle();
    expect(find.text('6001 selected'), findsOneWidget);
    expect(find.textContaining('The limit is 5,000'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Skip selected'))
            .onPressed,
        isNull);
    expect(api.previewBody, isNull);
  });
  testWidgets('failed initial page has a visible reload action',
      (tester) async {
    final api = ManagementApi()..failGroups = true;
    await openPage(tester, api);
    expect(find.text('Reload'), findsOneWidget);
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsNWidgets(2));
    expect(find.text('Reload'), findsNothing);
  });
  testWidgets(
      'all unfinished batches are accessible and ending one preserves the other',
      (tester) async {
    final api = ManagementApi()..failHistory = true;
    await openPage(tester, api);
    await tester.tap(find.text('Batches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Saved reminder older'), findsOneWidget);
    await tester.tap(find.text('End batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.states['older'], 'ENDED');
    expect(api.statuses['older'], 'STOPPED');
    expect(find.text('Resume batch'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(api.states['newer'], 'RUNNING');
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume batch'));
    await tester.pumpAndSettle();
    expect(api.statuses['newer'], 'SUCCESS');
  });
  testWidgets(
      'result details show safe reasons and retry only the chosen failure',
      (tester) async {
    final api = ManagementApi();
    await openPage(tester, api);
    await tester.tap(find.text('Batches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All batches'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('data integrity conflict'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retry-overdue-item-complete')));
    await tester.pumpAndSettle();
    expect(api.retryBody!['items'], [
      {'id': 'item-complete', 'attempts': 1}
    ]);
    expect(api.statuses['complete'], 'SUCCESS');
    expect(api.statuses['older'], 'PENDING');
    expect(find.text('Retry this item'), findsNothing);
  });
}
