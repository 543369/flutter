import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/care/care_pages.dart';
import 'widget_test.dart' show FakeApi, showCare, pendingTask;

class OverdueApi extends FakeApi {
  final requests = <String>[];
  Map<String, dynamic>? previewBody;
  bool done = false, loseFirstResponse = false;
  int applies = 0;
  final at = DateTime.now()
      .subtract(const Duration(days: 2))
      .toUtc()
      .toIso8601String();
  Map<String, dynamic> task(String id, String? group) => {
        ...pendingTask(id, group == null ? 'Medication' : 'Walk'),
        'planId': group,
        'revision': 0,
        'dueAt': at
      };
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    requests.add(path);
    final uri = Uri.parse(path);
    switch (uri.path) {
      case '/care/overdue/groups':
        return {
          'total': done ? 2 : 348,
          'recurringTotal': done ? 0 : 346,
          'singleTotal': 2,
          'asOf': DateTime.now().toUtc().toIso8601String(),
          'items': done
              ? []
              : [
                  for (final entry in {'plan-a': 331, 'plan-b': 15}.entries)
                    {
                      'id': entry.key,
                      'title': 'Walk',
                      'count': entry.value,
                      'firstAt': at,
                      'lastAt': at
                    }
                ],
          'hasMore': false,
          'nextCursor': '',
          'householdId': 'test',
        };
      case '/care/overdue/items':
        final group = uri.queryParameters['groupId'];
        if (group == 'single') {
          return {
            'items': [task('medical-1', null), task('medical-2', null)],
            'hasMore': false,
            'nextCursor': ''
          };
        }
        final offset = int.tryParse(uri.queryParameters['cursor'] ?? '') ?? 0;
        return {
          'items': [
            for (int i = offset; i < offset + 30; i++) task('$group-$i', group)
          ],
          'hasMore': offset == 0,
          'nextCursor': '30'
        };
      case '/care/overdue/batches/current':
        return {};
      case '/care/overdue/preview':
        previewBody = body;
        final count = (body!['allRecurring'] == true
                ? 346
                : (body['groupIds'] as List).contains('plan-a')
                    ? 331
                    : 15) -
            (body['excludedIds'] as List).length +
            (body['items'] as List).length;
        return {
          'id': 'job',
          'state': 'PREVIEW',
          'finished': false,
          'total': count,
          'remaining': count,
          'success': 0,
          'changed': 0,
          'failed': 0
        };
      case '/care/overdue/batches/job/apply':
        applies++;
        if (loseFirstResponse && applies == 1) {
          throw TimeoutException('response lost');
        }
        done = true;
        return {
          'id': 'job',
          'state': 'COMPLETE',
          'finished': true,
          'total': 346,
          'remaining': 0,
          'success': 345,
          'changed': 1,
          'failed': 0
        };
    }
    return super.request(method, path, body);
  }
}

Future<void> openPage(WidgetTester tester, OverdueApi api) async {
  await showCare(tester, api);
  final home = tester.state<CareHomeState>(find.byType(CareHome));
  unawaited(home.openOverdueCare());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'groups are collapsed and selecting all recurring never includes single reminders',
      (tester) async {
    final api = OverdueApi();
    await openPage(tester, api);
    expect(find.text('Walk'), findsNWidgets(2));
    expect(api.requests.where((v) => v.contains('groupId=plan-')), isEmpty);
    await tester.tap(find.text('Select recurring only'));
    await tester.pumpAndSettle();
    expect(find.text('346 selected'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('overdue-item-medical-1')))
            .value,
        false);
    await tester.tap(find.text('Skip selected'));
    await tester.pumpAndSettle();
    expect(api.previewBody!['allRecurring'], true);
    expect(api.previewBody!['items'], isEmpty);
    expect(api.applies, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('346 selected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'group selection covers unloaded pages and supports individual exclusions',
      (tester) async {
    final api = OverdueApi();
    await openPage(tester, api);
    await tester.tap(find.text('Select recurring only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walk').first);
    await tester.pumpAndSettle();
    expect(api.requests.any((v) => v.contains('groupId=plan-a')), true);
    await tester
        .ensureVisible(find.byKey(const ValueKey('overdue-item-plan-a-0')));
    await tester.tap(find.byKey(const ValueKey('overdue-item-plan-a-0')));
    await tester.pumpAndSettle();
    expect(find.text('345 selected'), findsOneWidget);
    await tester.tap(find.text('Skip selected'));
    await tester.pumpAndSettle();
    expect(api.previewBody!['excludedIds'], ['plan-a-0']);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'batch resumes with the same job after a lost response and shows changed count',
      (tester) async {
    final api = OverdueApi()..loseFirstResponse = true;
    await openPage(tester, api);
    await tester.tap(find.text('Select recurring only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.applies, 1);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(api.applies, 2);
    expect(api.requests.where((v) => v == '/care/overdue/preview').length, 1);
    expect(find.text('345 skipped · 1 changed · 0 failed'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
