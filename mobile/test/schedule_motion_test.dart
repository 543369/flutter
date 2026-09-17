import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/features/care/task_form_dialog.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

void main() {
  testWidgets('schedule tabs animate content and floating action opens form',
      (tester) async {
    await showCare(tester, FakeApi());
    await tapVisible(tester, find.text('All plans'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    final controller =
        tester.widget<TabBarView>(find.byType(TabBarView)).controller!;
    await tester.tap(find.text('Completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.animation!.value, greaterThan(0));
    expect(controller.animation!.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TaskFormDialog), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
