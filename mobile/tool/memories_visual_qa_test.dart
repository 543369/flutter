// Opt-in native captures:
// PETCARE_QA_FONT=/path/to/PingFang.ttc flutter test tool/memories_visual_qa_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/main.dart';
import '../test/memory_test.dart' show MemoryApi;
import '../test/widget_test.dart' show FakeReminders, tapVisible;

void main() {
  testWidgets('capture pet gallery, memories and family in Chinese',
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
    final api = MemoryApi()..token = 'visual-test';
    api.petItems = [
      {
        'id': 'pet',
        'name': 'KiMi',
        'species': 'cat',
        'birthDate': '2023-06-01',
        'biography': '喜欢在窗边晒太阳，也喜欢趴在家人身边打盹。',
        'createdAt': '2026-09-01T10:00:00Z'
      },
      {
        'id': 'doubao',
        'name': '豆包',
        'species': 'dog',
        'birthDate': '2024-04-01'
      },
    ];
    final photo = base64Encode(
        File('assets/images/petcare_cat_cover.jpg').readAsBytesSync());
    api.memories.add({
      'id': 'first',
      'petId': 'pet',
      'title': '有阳光的午后',
      'story':
          '今天的阳光刚刚好，KiMi 在窗边睡了一个长长的午觉。醒来后伸了个懒腰，又跑来蹭了蹭我的手。\n\n平凡的一天，因为有你，也值得好好收藏。',
      'happenedOn': '2026-09-12',
      'createdAt': '2026-09-12T08:00:00Z',
      'author': 'Junny',
      'photos': [photo]
    });
    final boundaryKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: PetCareApp(api: api, reminders: FakeReminders())));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final name in [
        'petcare_cat_cover.jpg',
        'petcare_shiba_hero.png',
        'petcare_food_bowl.png'
      ]) {
        await precacheImage(AssetImage('assets/images/$name'),
            tester.element(find.byType(PetCareApp)));
      }
      await precacheImage(MemoryImage(base64Decode(photo)),
          tester.element(find.byType(PetCareApp)));
    });
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
            '/private/tmp/petcare-memories-qa');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.tap(find.text('宠物'));
    await capture('pets-mobile');
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await capture('pets-desktop');
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pet-card-pet')));
    await capture('pet-detail');
    await tapVisible(tester, find.text('它的回忆录'));
    await capture('memories');
    await tapVisible(tester, find.text('有阳光的午后'));
    await capture('memory-detail');
    await tester.tap(find.byTooltip('编辑回忆'));
    await capture('memory-editor');
    await tapVisible(tester, find.text('照片 · 1/6'));
    await capture('memory-editor-photos');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('家庭'));
    await capture('family-mobile');
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await capture('family-desktop');
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('账号与偏好'));
    await capture('family-settings');
    await tester.pumpWidget(const SizedBox());
  });
}
