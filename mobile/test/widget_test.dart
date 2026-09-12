import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';
import 'package:petcare/main.dart';
import 'package:petcare/reminders.dart';

class FakeReminders extends ReminderService {
  List<Map<String, dynamic>> synced = [];
  bool grantPermission = true;
  int permissionRequests = 0;
  @override
  Future<bool> setEnabled(bool value) async {
    permissionRequests++;
    enabled = value && grantPermission;
    return enabled;
  }

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
  List<Map<String, dynamic>> recurring = [];
  int dashboardCalls = 0;
  Map<String, dynamic>? created;
  bool failNextSave = false;

  List<Map<String, dynamic>> petItems = [
    {'id': 'pet', 'name': 'Mochi', 'species': 'cat'}
  ];
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
  Future<Map<String, dynamic>> dashboard() async {
    dashboardCalls++;
    return {
      'pets': petItems,
      'tasks': items,
      'history': events,
      'plans': recurring,
      'me': 'Alex',
      'members': 2,
    };
  }

  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (failNextSave && (method == 'POST' || method == 'PATCH')) {
      failNextSave = false;
      throw const ApiError(503, 'TEST_UNAVAILABLE');
    }
    if (path == '/pets' && method == 'POST') {
      final pet = {
        ...body!,
        'id': 'new-pet',
        'createdAt': DateTime.now().toUtc().toIso8601String()
      };
      petItems.add(pet);
      return {'id': 'new-pet'};
    }
    if (path.startsWith('/pets/') && method == 'PATCH') {
      final pet = petItems
          .firstWhere((pet) => pet['id'] == path.substring('/pets/'.length));
      pet.addAll(body!);
      return {'id': pet['id']};
    }
    if (method == 'POST' && path == '/tasks') {
      created = body;
      final pet = petItems.firstWhere((pet) => pet['id'] == body!['petId']);
      final planId = body!['frequency'] == 'NONE' ? null : 'new-plan';
      items.add({
        ...body,
        'id': 'new-task',
        'petName': pet['name'],
        'completed': false,
        'planId': planId,
      });
      if (planId != null) {
        recurring.add(
            {...body, 'id': planId, 'petName': pet['name'], 'active': true});
      }
      return {'id': 'new-task'};
    }
    if (method == 'PATCH' && path.startsWith('/tasks/')) {
      final id = path.substring('/tasks/'.length);
      final task = items.firstWhere((task) => task['id'] == id);
      task['completed'] = body!['completed'];
      events.insert(0, {
        'id': 'event-${events.length}',
        'taskId': id,
        'petId': task['petId'],
        'action': body['completed'] == true ? 'COMPLETED' : 'REOPENED',
        'at': DateTime.now().toUtc().toIso8601String(),
        'actor': 'Alex',
        'title': task['title'],
        'petName': task['petName'],
        'careType': task['careType'],
      });
      return body;
    }
    throw StateError('Unexpected request: $method $path');
  }
}

Map<String, dynamic> pendingTask(String id, String title,
        {String petId = 'pet', String petName = 'Mochi', String? planId}) =>
    {
      'id': id,
      'petId': petId,
      'petName': petName,
      'title': title,
      'completed': false,
      'planId': planId,
      'dueAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    };

Future<void> showCare(WidgetTester tester, FakeApi api,
    [FakeReminders? reminders]) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  api.token = 'test';
  await tester.pumpWidget(
      PetCareApp(api: api, reminders: reminders ?? FakeReminders()));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('照护'));
    await tester.pumpAndSettle();
    expect(find.text('0 项待照护'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('complete care updates reminders and displays caregiver history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as done'));
    await tester.pumpAndSettle();
    expect(find.text('0 tasks to do'), findsOneWidget);
    expect(reminders.synced.first['completed'], true);
    await tester.ensureVisible(find.text('History'));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mochi · Alex'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to today'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('1 completed'));
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('1 tasks to do'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('all plans lists one-off care and creates for the selected pet',
      (tester) async {
    final api = FakeApi();
    api.petItems.add({'id': 'dog', 'name': 'Doubao', 'species': 'dog'});
    api.items = [
      pendingTask('care', 'Evening meal'),
      pendingTask('dog-care', 'Walk Doubao', petId: 'dog', petName: 'Doubao'),
    ];
    await showCare(tester, api);
    await tester.tap(find.byTooltip('Switch pet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doubao').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('All plans'));
    expect(find.text('Walk Doubao'), findsOneWidget);
    expect(find.text('Evening meal'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('create-schedule')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byType(DropdownButton<String>).first)
            .value,
        'dog');
    await tester.enterText(find.byType(TextField), 'Brush Doubao');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.created?['petId'], 'dog');
    expect(api.created?['frequency'], 'NONE');
    expect(find.text('Brush Doubao'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-schedule')), findsOneWidget);
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    expect(find.text('No recurring plans'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-schedule')), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-schedule')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recurring empty state creates weekly care and opens its details',
      (tester) async {
    final api = FakeApi();
    await showCare(tester, api);
    await tapVisible(tester, find.text('All plans'));
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-schedule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Weekly grooming');
    await tester.tap(find.text('Once'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.created?['frequency'], 'WEEKLY');
    expect(api.created?['zoneId'], 'Asia/Shanghai');
    await tester.tap(find.text('Weekly grooming'));
    await tester.pumpAndSettle();
    expect(find.text('Recurring plan details'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Asia/Shanghai'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Weekly grooming'));
    await tester.pumpAndSettle();
    expect(find.text('Plan details'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(api.items.single['completed'], false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('task details complete and undo care with linked event details',
      (tester) async {
    final api = FakeApi()..items = [pendingTask('care', 'Evening meal')];
    await showCare(tester, api);
    await tapVisible(tester, find.byKey(const ValueKey('next-care-details')));
    expect(find.text('Plan details'), findsOneWidget);
    expect(api.items.single['completed'], false);
    await tapVisible(tester, find.text('Mark as done'));
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Undo completion'), findsOneWidget);
    await tapVisible(tester, find.text('Care completed'));
    expect(find.text('Record details'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    await tester.tap(find.text('View linked plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan details'), findsOneWidget);
    await tapVisible(tester, find.text('Undo completion'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.items.single['completed'], false);
    expect(find.text('Pending'), findsOneWidget);
    await tapVisible(tester, find.text('Completion undone'));
    expect(find.text('Record details'), findsOneWidget);
    expect(find.text('Completion undone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'secondary task and home history cards open details without completing',
      (tester) async {
    final api = FakeApi()
      ..items = [
        pendingTask('care', 'Evening meal'),
        pendingTask('walk', 'Evening walk')
      ];
    api.events = [
      {
        'id': 'previous',
        'taskId': 'care',
        'petId': 'pet',
        'petName': 'Mochi',
        'title': 'Breakfast record',
        'actor': 'Alex',
        'action': 'REOPENED',
        'at': DateTime.now().toUtc().toIso8601String(),
      }
    ];
    await showCare(tester, api);
    await tapVisible(tester, find.text('Evening walk'));
    expect(find.text('Plan details'), findsOneWidget);
    expect(api.items.last['completed'], false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Breakfast record'));
    expect(find.text('Record details'), findsOneWidget);
    expect(find.text('Completion undone'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('History'));
    await tapVisible(tester, find.text('Breakfast record'));
    expect(find.text('Record details'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final granted in [true, false]) {
    testWidgets(
        'bell opens reminder settings without fetching dashboard (granted: $granted)',
        (tester) async {
      final api = FakeApi()..items = [pendingTask('care', 'Evening meal')];
      final reminders = FakeReminders()..grantPermission = granted;
      await showCare(tester, api, reminders);
      final calls = api.dashboardCalls;
      await tester.tap(find.byTooltip('Reminder settings'));
      await tester.pumpAndSettle();
      expect(find.text('Reminder settings'), findsOneWidget);
      expect(api.dashboardCalls, calls);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(reminders.permissionRequests, 1);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          granted);
      expect(api.dashboardCalls, calls);
      if (!granted) {
        expect(
            find.text(
                'Notifications are disabled. Allow them in system settings.'),
            findsOneWidget);
      } else {
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(reminders.enabled, false);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
