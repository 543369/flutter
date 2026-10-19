import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/care/care_actions.dart';
import 'package:petcare/features/care/care_pages.dart';
import 'package:petcare/features/care/care_day.dart';
import 'widget_test.dart' show FakeApi, FakeReminders, showCare, pendingTask;

class LegacyLaunchReminders extends FakeReminders {
  @override
  Future<void> initialize(ValueChanged<String?> onTap) async {
    ready = true;
    onTap(null);
  }
}

class PendingMutationApi extends FakeApi {
  final response = Completer<Map<String, dynamic>>();
  int writes = 0;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    writes++;
    return response.future;
  }
}

class SkipApi extends FakeApi {
  final skipped = <String>[];
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (method == 'POST' && path.endsWith('/dismiss')) {
      expect(body?['action'], 'SKIPPED');
      final id = path.split('/')[2];
      skipped.add(id);
      final task = items.firstWhere((v) => v['id'] == id);
      task['cancelled'] = true;
      return {...task};
    }
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets('today leads while old care is reviewed and skipped explicitly',
      (tester) async {
    final api = SkipApi()
      ..items = [
        {
          ...pendingTask('old', 'Old walk', planId: 'daily'),
          'dueAt': DateTime.now()
              .subtract(const Duration(days: 2))
              .toUtc()
              .toIso8601String()
        },
        pendingTask('today', 'Today meal'),
      ];
    await showCare(tester, api);
    expect(find.text('Today meal'), findsWidgets);
    expect(find.text('Old walk'), findsNothing);
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    unawaited(home.openOverdueCare());
    await tester.pumpAndSettle();
    expect(find.text('Old walk'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip selected (1)'));
    await tester.pumpAndSettle();
    expect(api.skipped, isEmpty);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.skipped, ['old']);
    expect(api.items.first['completed'], false);
    expect(find.text('No overdue care'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('legacy notification cold launch consumes a null payload safely',
      (tester) async {
    await showCare(tester, FakeApi(), LegacyLaunchReminders());
    final home =
        tester.state<CareHomeState>(find.byType(CareHome, skipOffstage: false));
    expect(home.pendingNotificationTap, false);
    expect(home.tab, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('notification opens the task from the API envelope',
      (tester) async {
    final api = FakeApi()..items = [pendingTask('one', 'Food')];
    final reminders = FakeReminders();
    await showCare(tester, api, reminders);
    reminders.onNotification!('one');
    await tester.pumpAndSettle();
    expect(find.text('Plan details'), findsOneWidget);
    final home =
        tester.state<CareHomeState>(find.byType(CareHome, skipOffstage: false));
    expect(home.detailTaskIds['one'], 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(home.detailTaskIds, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('duplicate care writes are blocked and failure releases state',
      (tester) async {
    final api = PendingMutationApi();
    await showCare(tester, api);
    final home =
        tester.state<CareHomeState>(find.byType(CareHome, skipOffstage: false));
    final write = home.mutateCare('health:one', '/reminder', {});
    final failure = expectLater(write, throwsStateError);
    expect(await home.mutateCare('health:one', '/reminder', {}), false);
    await tester.pump();
    expect(api.writes, 1);
    api.response.completeError(StateError('failed'));
    await failure;
    expect(home.submittingTasks, isEmpty);
    expect(home.taskWrites, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('local calendar day excludes yesterday and tomorrow', () {
    final day = DateTime(2026, 9, 17, 12);
    expect(
        careOnDay(DateTime(2026, 9, 17, 23, 59).toUtc().toIso8601String(), day),
        isTrue);
    expect(careOnDay(DateTime(2026, 9, 18).toUtc().toIso8601String(), day),
        isFalse);
    expect(
        careOnDay(DateTime(2026, 9, 16, 23, 59).toUtc().toIso8601String(), day),
        isFalse);
    expect(actionableCare({'completed': false, 'cancelled': true}), isFalse);
  });
  testWidgets('completion uses mutation response without a dashboard refresh',
      (tester) async {
    final api = FakeApi()..items = [pendingTask('one', 'Food')];
    await showCare(tester, api);
    final home =
        tester.state<CareHomeState>(find.byType(CareHome, skipOffstage: false));
    final before = api.dashboardCalls;
    await home.changeCompletion(home.tasks.single, true);
    await tester.pumpAndSettle();
    expect(api.dashboardCalls, before);
    expect(home.tasks.single['completed'], true);
    expect(home.submittingTasks, isEmpty);
    expect(home.data!['history'], isNotEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'failed completion preserves pending state and releases the button',
      (tester) async {
    final api = FakeApi()..items = [pendingTask('one', 'Food')];
    await showCare(tester, api);
    final home =
        tester.state<CareHomeState>(find.byType(CareHome, skipOffstage: false));
    api.failNextSave = true;
    await home.changeCompletion(home.tasks.single, true);
    await tester.pumpAndSettle();
    expect(home.tasks.single['completed'], false);
    expect(home.submittingTasks, isEmpty);
    expect(home.busy, false);
    await tester.pumpWidget(const SizedBox());
  });
}
