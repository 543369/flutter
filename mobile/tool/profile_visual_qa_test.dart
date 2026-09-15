// Opt-in: PETCARE_QA_FONT=/path/to/CJK.ttf flutter test tool/profile_visual_qa_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import '../test/personal_profile_test.dart' show ProfileApi;
import '../test/widget_test.dart' show FakeReminders, tapVisible;

void main() {
  testWidgets('capture personal profile and editor', (tester) async {
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

    final api = ProfileApi()..token = 'visual-test';
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
            '/private/tmp/petcare-profile-qa');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.text('家庭'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('个人资料'));
    await capture('profile');
    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();
    await capture('profile-editor');
    await tester.pumpWidget(const SizedBox());
  });
}
