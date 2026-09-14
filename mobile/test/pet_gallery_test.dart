import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/pets/pet_form_dialog.dart';
import 'package:petcare/features/pets/pet_profile.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

final galleryPhotos = List.generate(
    5,
    (n) => base64Encode(img.encodePng(
        img.Image(width: 2, height: 2)..setPixelRgb(0, 0, n * 40, 80, 50))));

void main() {
  test('gallery accepts old photos but explicit empty gallery clears the cover',
      () {
    expect(petPhotos({'photoData': galleryPhotos[0]}), [galleryPhotos[0]]);
    expect(petPhotos({'photos': [], 'photoData': galleryPhotos[0]}), isEmpty);
  });

  testWidgets(
      'pet editor caps at five, selects cover and retains images on failed save',
      (tester) async {
    final api = FakeApi()..failNextSave = true;
    await showCare(tester, api);
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    var picks = 0;
    showDialog<String>(
        context: home.context,
        builder: (_) => PetFormDialog(
            home: home, photoPicker: () async => galleryPhotos[picks++]));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('pet-name')), 'Five photos');
    for (var n = 0; n < 5; n++) {
      await tapVisible(tester, find.byKey(const ValueKey('add-pet-photo')));
    }
    expect(find.text('Pet photos · 5/5'), findsOneWidget);
    final button = tester
        .widget<OutlinedButton>(find.byKey(const ValueKey('add-pet-photo')));
    expect(button.onPressed, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('cover-pet-photo-4')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.petItems, hasLength(1));
    expect(find.text('Pet photos · 5/5'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.petItems.last['photos'],
        [galleryPhotos[4], ...galleryPhotos.take(4)]);
    expect(api.petItems.last['photoData'], galleryPhotos[4]);
    expect(picks, 5);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'removing every old profile photo explicitly saves an empty gallery',
      (tester) async {
    final api = FakeApi();
    api.petItems.single['photoData'] = galleryPhotos[0];
    await showCare(tester, api);
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    showDialog<String>(
        context: home.context,
        builder: (_) => PetFormDialog(home: home, pet: api.petItems.single));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('remove-pet-photo-0')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.petItems.single['photos'], isEmpty);
    expect(api.petItems.single['photoData'], isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'home pages current pet photos; switching pets and editing gallery reset the page',
      (tester) async {
    final api = FakeApi();
    api.petItems = [
      {'id': 'pet', 'name': 'Mochi', 'species': 'cat', 'photos': galleryPhotos},
      {
        'id': 'dog',
        'name': 'Doubao',
        'species': 'dog',
        'photos': [galleryPhotos[0]]
      },
    ];
    await showCare(tester, api);
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    PageView pages() =>
        tester.widget<PageView>(find.byKey(const ValueKey('pet-photo-pages')));
    await tester.dragFrom(const Offset(340, 230), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(pages().controller!.page, 1);
    expect(home.selectedPet?['id'], 'pet');
    await tester.dragFrom(const Offset(125, 165), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(pages().controller!.page, 2);
    await tester.tap(find.byKey(const ValueKey('pet-photo-dot-4')));
    await tester.pumpAndSettle();
    expect(pages().controller!.page, 4);
    await tester.tap(find.byTooltip('Switch pet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doubao').last);
    await tester.pumpAndSettle();
    expect(home.selectedPet?['id'], 'dog');
    expect(pages().controller!.page, 0);
    expect(find.byKey(const ValueKey('pet-photo-dot-0')), findsNothing);
    home.updateUi(() => home.selectedPetId = 'pet');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pet-photo-dot-4')));
    await tester.pumpAndSettle();
    api.petItems.first['photos'] = [galleryPhotos[1], galleryPhotos[2]];
    await home.refreshQuietly();
    await tester.pumpAndSettle();
    expect(pages().controller!.page, 0);
    expect(find.byKey(const ValueKey('pet-photo-dot-2')), findsNothing);
    api.petItems.first['photos'] = [];
    await home.refreshQuietly();
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
