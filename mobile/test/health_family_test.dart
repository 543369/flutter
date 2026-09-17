import 'package:petcare/core/widgets/app_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';
import 'package:petcare/features/health/health_pages.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

class HealthFamilyApi extends FakeApi {
  final health = <Map<String, dynamic>>[];
  final members = <Map<String, dynamic>>[
    {
      'id': 'owner',
      'name': 'Alex',
      'role': 'ADMIN',
      'permissions': ['CARE', 'HEALTH', 'MEMORIES', 'PETS', 'REPORTS'],
      'expiresAt': null,
      'isMe': true
    },
    {
      'id': 'member',
      'name': 'Robin',
      'role': 'MEMBER',
      'permissions': ['CARE', 'HEALTH', 'MEMORIES', 'PETS', 'REPORTS'],
      'expiresAt': null,
      'isMe': false
    }
  ];
  bool advanced = true, failHealth = false;
  Map<String, dynamic>? savedRole;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path.startsWith('/pets/pet/health?')) {
      return {
        'items': health,
        'hasMore': false,
        'total': health.length,
        'advanced': advanced,
        'attachmentLimit': advanced ? 12 : 2
      };
    }
    if (path == '/pets/pet/health' && method == 'POST') {
      if (failHealth) {
        failHealth = false;
        throw const ApiError(503, 'UNAVAILABLE');
      }
      health.add({
        ...body!,
        'id': 'health-1',
        'folder': '',
        'createdAt': '2026-09-15T01:00:00Z',
        'updatedAt': '2026-09-15T01:00:00Z'
      });
      return {'id': 'health-1'};
    }
    if (path == '/pets/pet/health/health-1/reminder' && method == 'POST') {
      final task = <String, dynamic>{
        'id': 'health-task',
        'petId': 'pet',
        'petName': 'Mochi',
        'title': health.single['title'],
        'dueAt': body!['dueAt'],
        'completed': false,
        'cancelled': false,
        'careType': 'VACCINE',
        'healthRecordId': 'health-1'
      };
      items.removeWhere((v) => v['id'] == 'health-task');
      items.add(task);
      health.single['careReminders'] = [task];
      return {'task': task, 'events': []};
    }
    if (path == '/pets/pet/health/health-1') return health.single;
    if (path == '/family/members') {
      return {'items': members, 'canManage': true, 'advanced': advanced};
    }
    if (path == '/family/members/member' && method == 'PATCH') {
      savedRole = body;
      members[1].addAll(body!);
      return {'saved': true};
    }
    if (path.startsWith('/family/weekly?')) {
      return {
        'advanced': advanced,
        'due': 2,
        'completed': 1,
        'missed': 1,
        'completionRate': 50.0,
        'unassigned': 1,
        'pets': [
          {'name': 'Mochi', 'due': 2, 'completed': 1, 'missed': 1}
        ],
        'members': [
          {'name': 'Alex', 'assigned': 1, 'completed': 1}
        ],
        'missedTasks': [
          {
            'id': 'missed',
            'petName': 'Mochi',
            'title': 'Evening meal',
            'dueAt': '2026-09-15T00:00:00Z'
          }
        ],
        'trends': []
      };
    }
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets('basic health records save after retry and open details',
      (tester) async {
    final api = HealthFamilyApi()..advanced = false;
    await showCare(tester, api);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pet-card-pet')));
    await tapVisible(tester, find.text('Health records'));
    expect(
        find.text('No health records yet. Add the first one.'),
        findsOneWidget);
    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Annual vaccination');
    api.failHealth = true;
    await tapVisible(tester, find.text('Save record'));
    expect(find.byType(HealthRecordEditor), findsOneWidget);
    expect(find.text('Annual vaccination'), findsOneWidget);
    await tapVisible(tester, find.text('Save record'));
    expect(api.health.length, 1);
    await tapVisible(tester, find.text('Annual vaccination'));
    expect(find.text('Health record details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('health record schedules linked care without reloading dashboard',
      (tester) async {
    final api = HealthFamilyApi();
    api.health.add({
      'id': 'health-1',
      'kind': 'VACCINE',
      'title': 'Annual vaccine',
      'notes': 'Vet instructions',
      'happenedOn': '2026-09-15',
      'photos': [],
      'folder': '',
      'createdAt': '2026-09-15T01:00:00Z',
      'careReminders': []
    });
    await showCare(tester, api);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pet-card-pet')));
    await tapVisible(tester, find.text('Health records'));
    await tapVisible(tester, find.text('Annual vaccine'));
    final calls = api.dashboardCalls;
    await tapVisible(tester, find.text('Set next care reminder'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(api.items.single['healthRecordId'], 'health-1');
    expect(api.dashboardCalls, calls);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(ListTile, 'Pending'));
    expect(find.text('Plan details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('View health record'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('View health record'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('weekly report and temporary role permissions can be configured',
      (tester) async {
    final api = HealthFamilyApi();
    await showCare(tester, api);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Weekly report & pet trends'));
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('People and permissions'));
    await tapVisible(tester, find.text('Robin'));
    await tester.tap(find.byType(AppSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporary caregiver').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save permissions'));
    expect(api.savedRole!['role'], 'TEMP');
    expect(api.savedRole!['permissions'], ['CARE']);
    expect(api.savedRole!['expiresAt'], isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
