import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';
import 'package:petcare/main.dart';
import 'package:petcare/reminders.dart';

class FakeReminders extends ReminderService {
  List<Map<String, dynamic>> synced = [];
  @override
  Future<void> initialize(VoidCallback onTap) async {
    ready = true;
  }

  @override
  Future<void> sync(List<Map<String, dynamic>> tasks,
      {required bool chinese}) async {
    synced = tasks;
  }

  @override
  Future<String> deviceZone() async => 'Asia/Shanghai';
}

class FakeApi extends CareApi {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> events = [];
  @override
  Future<void> restore() async {}
  @override
  Future<void> login(String email, String password) async {
    token = 'test';
  }

  @override
  Future<void> createSession() async {
    token = 'test';
  }

  @override
  Future<Map<String, dynamic>> dashboard() async => {
        'pets': [
          {'id': 'pet', 'name': 'Mochi', 'species': 'cat'}
        ],
        'tasks': items,
        'history': events,
        'plans': [],
        'me': 'Alex',
        'members': 2,
      };
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (method == 'PATCH' && path == '/tasks/care') {
      items = [
        {...items.first, 'completed': body!['completed']}
      ];
      events = [
        {
          'id': 'event',
          'taskId': 'care',
          'action': body['completed'] == true ? 'COMPLETED' : 'REOPENED',
          'at': DateTime.now().toUtc().toIso8601String(),
          'actor': 'Alex',
          'title': 'Evening meal',
          'petName': 'Mochi'
        }
      ];
      return body;
    }
    throw StateError('Unexpected request: $method $path');
  }
}

void main() {
  testWidgets('onboarding opens care board and switches language',
      (tester) async {
    await tester
        .pumpWidget(PetCareApp(api: FakeApi(), reminders: FakeReminders()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'test-password-123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('0 tasks to do'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch language'));
    await tester.pumpAndSettle();
    expect(find.text('0 项待照护'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('complete care updates reminders and displays caregiver history',
      (tester) async {
    final api = FakeApi()..token = 'test';
    api.items = [
      {
        'id': 'care',
        'petId': 'pet',
        'petName': 'Mochi',
        'title': 'Evening meal',
        'completed': false,
        'dueAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'planId': null
      }
    ];
    final reminders = FakeReminders();
    await tester.pumpWidget(PetCareApp(api: api, reminders: reminders));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('0 tasks to do'), findsOneWidget);
    expect(reminders.synced.first['completed'], true);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alex · Completed'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('1 tasks to do'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
