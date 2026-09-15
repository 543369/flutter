// Opt-in: PETCARE_QA_FONT=/path/to/CJK.ttf flutter test tool/health_family_visual_qa_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import '../test/health_family_test.dart' show HealthFamilyApi;
import '../test/widget_test.dart' show FakeReminders, tapVisible;

void main() {
  testWidgets('capture health, weekly report and household roles',
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

    final api = HealthFamilyApi()..token = 'visual-test';
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
            '/private/tmp/petcare-health-family-qa');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.text('宠物'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pet-card-pet')));
    await tapVisible(tester, find.text('健康档案'));
    await capture('health-records');
    await tester.tap(find.text('新增记录'));
    await capture('health-editor');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家庭'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('家庭周报与多宠统计'));
    await capture('weekly-report');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('家人与照护权限'));
    await capture('family-roles');
    await tapVisible(tester, find.text('Robin'));
    await capture('role-editor');
    await tester.pumpWidget(const SizedBox());
  });
}
