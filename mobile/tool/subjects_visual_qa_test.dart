// Opt-in layout verification, using isolated fixture data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/pets/pet_form_dialog.dart';
import 'package:petcare/features/pets/subject_access_page.dart';
import 'package:petcare/features/care/task_form_dialog.dart';
import 'package:petcare/features/subjects/medication_page.dart';
import '../test/subject_profiles_test.dart' show SubjectApi;
import '../test/widget_test.dart' show FakeReminders;

void main() {
  testWidgets('capture unified profiles and human care flows', (tester) async {
    await tester.runAsync(() async {
      final data = ByteData.sublistView(
          await File('assets/fonts/NotoSansSC-Regular.ttf').readAsBytes());
      for (final family in ['SF Pro Display', 'Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(Future.value(data))).load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    tester.platformDispatcher.localesTestValue = [const Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final scene in [
      'profiles-phone',
      'person-form',
      'human-tasks',
      'sharing-phone',
      'medication-phone',
      'profiles-wide',
      'child-tasks',
      'child-recovery-tasks',
      'elder-tasks'
    ]) {
      await tester.binding.setSurfaceSize(
          scene.endsWith('wide') ? const Size(900, 700) : const Size(393, 852));
      final api = SubjectApi()..token = 'subject-review';
      final person = {
        'id': 'human',
        'name': scene.startsWith('child') ? '小禾' : '妈妈',
        'species': 'other',
        'subjectType': 'HUMAN',
        'relationship': scene.startsWith('child') ? '孩子' : '母亲',
        'lifeStage': scene.startsWith('child') ? 'CHILD' : 'ELDER',
        'careScenarios':
            scene.contains('recovery') ? ['DAILY', 'RECOVERY'] : ['DAILY'],
        'canManageSubject': true,
        'canCareSubject': true,
        'birthDate': scene.startsWith('child') ? '2021-01-01' : '1960-01-01',
        'biography': '喜欢清淡饮食，照护前先沟通。'
      };
      api.petItems = [
        person,
        {'id': 'pet', 'name': 'KiMi', 'species': 'dog', 'subjectType': 'PET'}
      ];
      api.items = [];
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: PetCareApp(api: api, reminders: FakeReminders())));
      await tester.pumpAndSettle();
      final home = tester.state<CareHomeState>(find.byType(CareHome));
      switch (scene) {
        case 'profiles-phone':
        case 'profiles-wide':
          await tester.tap(find.text('照护对象'));
          break;
        case 'person-form':
          showDialog<String>(
              context: tester.element(find.byType(CareHome)),
              builder: (_) => PetFormDialog(home: home));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('subject-type')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('家人').last);
          break;
        case 'child-tasks':
        case 'child-recovery-tasks':
        case 'elder-tasks':
        case 'human-tasks':
          showDialog<String>(
              context: tester.element(find.byType(CareHome)),
              builder: (_) => TaskFormDialog(home: home, petId: 'human'));
          break;
        case 'sharing-phone':
          Navigator.of(tester.element(find.byType(CareHome))).push(
              MaterialPageRoute<void>(
                  builder: (_) =>
                      SubjectAccessPage(home: home, subject: person)));
          break;
        case 'medication-phone':
          Navigator.of(tester.element(find.byType(CareHome)))
              .push(MaterialPageRoute<void>(
                  builder: (_) => MedicationPage(home: home, task: {
                        'id': 'med',
                        'title': '按医嘱用药',
                        'petId': 'human',
                        'careType': 'MEDICATION',
                        'revision': 0
                      })));
          break;
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('/private/tmp/family-care-subjects');
        await dir.create(recursive: true);
        await File('${dir.path}/$scene.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
