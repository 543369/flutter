// Opt-in: PETCARE_QA_FONT=/path/to/CJK.ttf flutter test tool/health_family_visual_qa_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import '../test/widget_test.dart' show FakeApi, pendingTask;
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/care/care_pages.dart';
import '../test/widget_test.dart' show FakeReminders, tapVisible;

void main() {
  testWidgets('capture care home, details, schedules and history',
      (tester) async {
    final fontPath = Platform.environment['PETCARE_QA_FONT'];
    if (fontPath == null) {
      throw StateError('Set PETCARE_QA_FONT to a CJK font file.');
    }
    await tester.runAsync(() async {
      final bytes = ByteData.sublistView(await File(fontPath).readAsBytes());
      for (final family in ['SF Pro Display', 'Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    tester.platformDispatcher.localesTestValue = [const Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final api = FakeApi()..token = 'visual-test';
    api.petItems = [
      {'id': 'pet', 'name': '豆包', 'species': 'dog'},
      {'id': 'cat', 'name': '团子', 'species': 'cat'}
    ];
    final now = DateTime.now();
    api.items = [
      {
        ...pendingTask('meal', '晚饭', petName: '豆包'),
        'careType': 'FEEDING',
        'dueAt':
            now.subtract(const Duration(hours: 1)).toUtc().toIso8601String()
      },
      {
        ...pendingTask('walk', '晚间散步', petName: '豆包'),
        'careType': 'WALK',
        'dueAt': DateTime(now.year, now.month, now.day + 1, 18)
            .toUtc()
            .toIso8601String()
      },
      pendingTask('cat-care', '驱虫', petId: 'cat', petName: '团子'),
    ];
    api.events = [
      {
        'id': 'event',
        'taskId': 'meal',
        'petId': 'pet',
        'petName': '豆包',
        'title': '早餐',
        'actor': 'Alex',
        'action': 'COMPLETED',
        'at': now.toUtc().toIso8601String()
      }
    ];
    final boundaryKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: PetCareApp(api: api, reminders: FakeReminders())));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      // Await each visible provider: newly decoded byte arrays have distinct
      // cache keys, so preloading another MemoryImage does not await this frame.
      final visibleImages =
          tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        for (final widget in visibleImages) {
          await precacheImage(
              widget.image, tester.element(find.byType(PetCareApp)));
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory(Platform.environment['PETCARE_QA_OUTPUT'] ??
            '/private/tmp/petcare-care-rounds-qa');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home');
    await tapVisible(tester, find.byKey(const ValueKey('next-care-details')));
    await capture('detail');
    await tester.drag(find.byType(ListView).last, const Offset(0, -380));
    await tester.pumpAndSettle();
    await capture('detail-actions');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    home.openSchedules();
    await tester.pumpAndSettle();
    await capture('schedules');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    home.openCareHistory();
    await tester.pumpAndSettle();
    await capture('history');
    await tester.pumpWidget(const SizedBox());
  });
}
