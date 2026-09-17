import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show FakeApi, showCare;

void main() {
  testWidgets('home hero collapses and expands with scroll', (tester) async {
    await showCare(tester, FakeApi());
    final header = find.descendant(
      of: find.byType(SliverPersistentHeader), matching: find.byType(ClipRect)).first;
    expect(tester.getSize(header).height, 392);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, lessThan(392));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, 392);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
