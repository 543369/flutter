// Opt-in rendered layout review with isolated in-memory data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import '../test/widget_test.dart' show FakeReminders;
import '../test/overdue_care_page_test.dart' show OverdueApi;
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/care/care_pages.dart';
import 'dart:async';

void main() {
  testWidgets('capture grouped overdue page on phone and desktop',
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
    for (final state in ['wide', 'phone']) {
      final wide = state == 'wide';
      await tester.binding
          .setSurfaceSize(wide ? const Size(900, 650) : const Size(393, 852));
      final api = OverdueApi()..token = 'overdue-review';
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: PetCareApp(api: api, reminders: FakeReminders())));
      await tester.pumpAndSettle();
      final home = tester.state<CareHomeState>(find.byType(CareHome));
      unawaited(home.openOverdueCare());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final widget in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(
              widget.image, tester.element(find.byType(PetCareApp)));
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('只选重复事项'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory(Platform.environment['PETCARE_QA_OUTPUT'] ??
            '/private/tmp/petcare-overdue-after');
        await dir.create(recursive: true);
        await File('${dir.path}/$state.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
