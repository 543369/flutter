import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

void main() {
  testWidgets('privacy expansion and family scroll restore independently',
      (tester) async {
    await showCare(tester, FakeApi());
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Data & privacy'));
    expect(tester.takeException(), isNull);
    expect(find.text('Delete my account'), findsOneWidget);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Data & privacy'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Delete my account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
