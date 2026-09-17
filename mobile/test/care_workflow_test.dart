import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/care/care_actions.dart';
import 'package:petcare/features/care/care_day.dart';
import 'widget_test.dart' show FakeApi, FakeReminders, showCare, pendingTask;

class LegacyLaunchReminders extends FakeReminders {
  @override
  Future<void> initialize(ValueChanged<String?> onTap) async {
    ready = true;
    onTap(null);
  }
}

void main() {
  testWidgets('legacy notification cold launch consumes a null payload safely',
      (tester) async {
    await showCare(tester, FakeApi(), LegacyLaunchReminders());
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    expect(home.pendingNotificationTap, false);
    expect(home.tab, 0);
    expect(tester.takeException(), isNull);
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
    final home = tester.state<CareHomeState>(find.byType(CareHome));
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
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    api.failNextSave = true;
    await home.changeCompletion(home.tasks.single, true);
    await tester.pumpAndSettle();
    expect(home.tasks.single['completed'], false);
    expect(home.submittingTasks, isEmpty);
    expect(home.busy, false);
    await tester.pumpWidget(const SizedBox());
  });
}
