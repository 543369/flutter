import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/features/pets/pet_profile.dart';
import 'widget_test.dart' show FakeApi, pendingTask, showCare, tapVisible;

void main() {
  test('age uses birthdays, leap years and optional unknown dates', () {
    expect(petAgeLabel('2024-09-13', DateTime(2026, 9, 12), chinese: true),
        '1 岁 11 个月');
    expect(
        petAgeLabel('2024-09-12', DateTime(2026, 9, 12), chinese: true), '2 岁');
    expect(
        petAgeLabel('2024-02-29', DateTime(2025, 2, 28), chinese: true), '1 岁');
    expect(petAgeLabel('2026-09-01', DateTime(2026, 9, 12), chinese: true),
        '11 天');
    expect(petAgeLabel(null, DateTime(2026, 9, 12), chinese: true), '年龄未填写');
    expect(petAgeLabel('2027-01-01', DateTime(2026, 9, 12), chinese: true),
        '年龄未填写');
  });

  testWidgets(
      'presets supply editable titles, persist category and render its image',
      (tester) async {
    final api = FakeApi()..items = [pendingTask('care', 'Evening meal')];
    await showCare(tester, api);
    await tapVisible(tester, find.text('All plans'));
    await tester.tap(find.text('New plan'));
    await tester.pumpAndSettle();
    for (final code in ['FEEDING', 'DEWORMING', 'VACCINE']) {
      await tapVisible(tester, find.byKey(ValueKey('care-type-$code')));
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('task-title')))
              .controller!
              .text,
          isNotEmpty);
    }
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Annual vaccine appointment');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.created?['careType'], 'VACCINE');
    expect(api.created?['title'], 'Annual vaccine appointment');
    await tapVisible(tester, find.text('Annual vaccine appointment'));
    expect(find.text('Plan details'), findsOneWidget);
    expect(find.text('Vaccination'), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/care_vaccine.jpg'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom plan keeps user input when saving fails and allows retry',
      (tester) async {
    final api = FakeApi()..failNextSave = true;
    await showCare(tester, api);
    await tapVisible(tester, find.text('New plan'));
    await tapVisible(tester, find.byKey(const ValueKey('care-type-CUSTOM')));
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Practice recall together');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Practice recall together'), findsOneWidget);
    expect(
        find.text(
            'Connection failed. Check your network and API URL, then retry.'),
        findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.created?['careType'], 'CUSTOM');
    expect(api.items.single['title'], 'Practice recall together');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pet creation saves birthday biography and server creation time, then details edit preserves time',
      (tester) async {
    final api = FakeApi();
    await showCare(tester, api);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Add a pet'));
    await tester.enterText(find.byKey(const ValueKey('pet-name')), 'Doubao');
    await tapVisible(tester, find.byKey(const ValueKey('pet-birthday')));
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '01/02/2020');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pet-biography')),
        'Loves sunshine and afternoon naps.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final pet = api.petItems.last;
    expect(pet['birthDate'], '2020-01-02');
    expect(pet['biography'], 'Loves sunshine and afternoon naps.');
    final created = pet['createdAt'];
    expect(created, isNotNull);
    await tapVisible(tester, find.text('Doubao'));
    expect(find.text('Pet profile'), findsOneWidget);
    await tapVisible(tester, find.text('Edit profile'));
    await tester.enterText(
        find.byKey(const ValueKey('pet-biography')), 'A gentle companion.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.petItems.last['createdAt'], created);
    expect(api.petItems.last['birthDate'], '2020-01-02');
    expect(find.text('A gentle companion.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'old pet profile displays unknown dates and retains edits on failure',
      (tester) async {
    final api = FakeApi()..failNextSave = true;
    await showCare(tester, api);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Mochi'));
    expect(find.text('Pet profile'), findsOneWidget);
    await tester.ensureVisible(find.text('Not recorded (older profile)'));
    expect(find.text('Not recorded (older profile)'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('pet-biography')), 'Very curious.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Very curious.'), findsOneWidget);
    expect(
        find.text(
            'Connection failed. Check your network and API URL, then retry.'),
        findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.petItems.single['biography'], 'Very curious.');
    expect(api.petItems.single['birthDate'], isNull);
    expect(api.petItems.single['createdAt'], isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
