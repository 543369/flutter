// Opt-in rendered layout review with isolated in-memory data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import '../test/widget_test.dart' show FakeApi, FakeReminders, pendingTask;

void main() {
  testWidgets('capture care section spacing on phone and desktop',
      (tester) async {
    await tester.runAsync(() async {
      final bytes = ByteData.sublistView(
          await File('assets/fonts/NotoSansSC-Regular.ttf').readAsBytes());
      for (final family in ['SF Pro Display', 'Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    tester.platformDispatcher.localesTestValue = [const Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    for (final state in ['wide', 'phone', 'empty', 'important']) {
      final wide = state == 'wide';
      await tester.binding
          .setSurfaceSize(wide ? const Size(900, 650) : const Size(393, 852));
      final api = FakeApi()..token = 'spacing-review';
      api.petItems = [
        {'id': 'pet', 'name': 'KiMi', 'species': 'dog'}
      ];
      api.items = [
        if (state != 'empty')
          {
            ...pendingTask('today', '散步', planId: 'daily'),
            'careType': 'WALK',
            'dueAt': DateTime(now.year, now.month, now.day, 18)
                .toUtc()
                .toIso8601String()
          },
        {
          ...pendingTask('old', '散步', planId: 'daily'),
          'careType': 'WALK',
          'dueAt':
              now.subtract(const Duration(days: 2)).toUtc().toIso8601String()
        },
        if (state == 'important')
          {
            ...pendingTask('medical', '就诊复查'),
            'careType': 'CUSTOM',
            'dueAt':
                now.subtract(const Duration(days: 1)).toUtc().toIso8601String()
          },
        {
          ...pendingTask('future', '散步', planId: 'daily'),
          'careType': 'WALK',
          'dueAt': now.add(const Duration(days: 2)).toUtc().toIso8601String()
        },
      ];
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: PetCareApp(api: api, reminders: FakeReminders())));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -330));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final widget in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(
              widget.image, tester.element(find.byType(PetCareApp)));
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory(Platform.environment['PETCARE_QA_OUTPUT'] ??
            '/private/tmp/petcare-spacing-after');
        await dir.create(recursive: true);
        await File('${dir.path}/$state.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
