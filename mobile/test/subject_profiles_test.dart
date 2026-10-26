import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/pets/pet_form_dialog.dart';
import 'package:petcare/features/pets/subject_access_page.dart';
import 'package:petcare/features/care/task_form_dialog.dart';
import 'package:petcare/features/subjects/medication_page.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

class SubjectApi extends FakeApi {
  Map<String, dynamic>? profile, medication;
  String grant = 'NONE';
  bool active = true;
  final logs = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/subjects' && method == 'POST') {
      profile = body;
      return {'id': 'human'};
    }
    if (path == '/subjects/human/access') {
      return {
        'consentActive': active,
        'basis': 'REPRESENTATIVE',
        'members': [
          {'id': 'member', 'name': 'Robin', 'accessLevel': grant}
        ],
        'events': []
      };
    }
    if (path == '/subjects/human/access/member') {
      grant = body!['level'] as String;
      return {'level': grant};
    }
    if (path == '/subjects/human/consent') {
      active = !(body!['revoke'] as bool);
      grant = 'NONE';
      return {'active': active};
    }
    if (path == '/tasks/med/medication') {
      if (method == 'POST') {
        medication = body;
        logs.add({'id': 'log', ...body!});
        return {};
      }
      return {'items': logs};
    }
    return super.request(method, path, body);
  }
}

Future<CareHomeState> home(WidgetTester tester, SubjectApi api) async {
  api.petItems = [
    {
      'id': 'human',
      'name': 'Mom',
      'subjectType': 'HUMAN',
      'species': 'other',
      'relationship': 'Mother',
      'canManageSubject': true,
      'canCareSubject': true
    }
  ];
  await showCare(tester, api);
  return tester.state<CareHomeState>(find.byType(CareHome));
}

void main() {
  testWidgets(
      'human profile requires authorization and stores relationship without species',
      (tester) async {
    final api = SubjectApi();
    final state = await home(tester, api);
    Navigator.of(state.context).push(
        MaterialPageRoute<void>(builder: (_) => PetFormDialog(home: state)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subject-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Person').last);
    await tester.pumpAndSettle();
    expect(find.text('Species'), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('subject-life-stage')));
    await tester.tap(find.text('Child').last);
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const ValueKey('subject-scenario-RECOVERY')));
    await tester.enterText(find.byKey(const ValueKey('pet-name')), 'Mom');
    await tester.enterText(
        find.byKey(const ValueKey('subject-relationship')), 'Mother');
    await tapVisible(tester, find.text('Save'));
    expect(api.profile, isNull);
    expect(find.text('Enter the relationship and confirm authorization.'),
        findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('subject-consent')));
    await tapVisible(tester, find.text('Save'));
    expect(api.profile!['lifeStage'], 'CHILD');
    expect(api.profile!['careScenarios'], ['DAILY', 'RECOVERY']);
    expect(api.profile!['relationship'], 'Mother');
    expect(api.profile!['consentConfirmed'], true);
    expect(api.profile!.containsKey('species'), false);
    expect(api.profile!.containsKey('photos'), false);
  });
  testWidgets('human templates exclude animal care categories', (tester) async {
    final state = await home(tester, SubjectApi());
    Navigator.of(state.context).push(MaterialPageRoute<void>(
        builder: (_) => TaskFormDialog(home: state, petId: 'human')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('care-type-DEWORMING')), findsNothing);
    expect(find.byKey(const ValueKey('care-type-FEEDING')), findsNothing);
    expect(find.byKey(const ValueKey('care-type-MEDICATION')), findsOneWidget);
    expect(find.byKey(const ValueKey('care-type-REHAB')), findsOneWidget);
  });
  testWidgets('sharing is explicit and revocation clears grants',
      (tester) async {
    final api = SubjectApi();
    final state = await home(tester, api);
    Navigator.of(state.context).push(MaterialPageRoute<void>(
        builder: (_) =>
            SubjectAccessPage(home: state, subject: api.petItems.first)));
    await tester.pumpAndSettle();
    expect(find.text('No access'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('subject-access-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Care').last);
    await tester.pumpAndSettle();
    expect(api.grant, 'CARE');
    await tapVisible(tester, find.text('Revoke'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.active, false);
    expect(api.grant, 'NONE');
  });
  testWidgets('medication records explicit not-taken outcome and actual time',
      (tester) async {
    final api = SubjectApi();
    final state = await home(tester, api);
    Navigator.of(state.context).push(MaterialPageRoute<void>(
        builder: (_) => MedicationPage(home: state, task: {
              'id': 'med',
              'petId': 'human',
              'title': 'Prescribed medicine',
              'careType': 'MEDICATION',
              'revision': 3,
              'completed': false
            })));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'per prescription');
    await tester.tap(find.byKey(const ValueKey('medication-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not taken').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save medication outcome'));
    expect(api.medication!['outcome'], 'NOT_TAKEN');
    expect(api.medication!['revision'], 3);
    expect(
        DateTime.parse(api.medication!['actualAt'] as String)
            .isAfter(DateTime.now()),
        false);
    expect(find.text('Not taken'), findsOneWidget);
  });

  testWidgets(
      'view-only human access displays medication history without an editable form',
      (tester) async {
    final api = SubjectApi();
    final state = await home(tester, api);
    api.petItems.first['canCareSubject'] = false;
    state.updateUi(() => state.data!['pets'] = api.petItems);
    Navigator.of(state.context).push(MaterialPageRoute<void>(
        builder: (_) => MedicationPage(home: state, task: {
              'id': 'med',
              'petId': 'human',
              'title': 'Medicine',
              'careType': 'MEDICATION',
              'revision': 0
            })));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save medication outcome'), findsNothing);
  });
}
