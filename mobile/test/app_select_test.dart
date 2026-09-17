import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/widgets/app_select.dart';

void main() {
  testWidgets('selector clips menu with no edge gaps and updates selection',
      (tester) async {
    String? value = 'a';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => SizedBox(
          width: 280,
          child: AppSelect<String>(
            initialValue: value,
            decoration: const InputDecoration(labelText: 'Pet'),
            items: const [
              DropdownMenuItem(value: 'a', child: Text('Doubao')),
              DropdownMenuItem(value: 'b', child: Text('Niangao'))
            ],
            onChanged: (v) => setState(() => value = v),
          )),
    ))));
    final menu = tester
        .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
    expect(menu.borderRadius, BorderRadius.circular(18));
    expect(menu.offset, const Offset(0, 8));
    expect(menu.initialValue, isNull);
    expect(menu.menuPadding, EdgeInsets.zero);
    expect(menu.clipBehavior, Clip.antiAlias);
    await tester.tap(find.byType(AppSelect<String>));
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.byType(PopupMenuItem<String>).first).dy,
        greaterThanOrEqualTo(
            tester.getBottomLeft(find.byType(AppSelect<String>)).dy + 8));
    await tester.tap(find.text('Niangao'));
    await tester.pumpAndSettle();
    expect(value, 'b');
    expect(find.text('Doubao'), findsNothing);
  });
  testWidgets('disabled selector cannot open menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AppSelect<String>(
      initialValue: 'a',
      items: [DropdownMenuItem(value: 'a', child: Text('Pet'))],
      onChanged: null,
    ))));
    await tester.tap(find.byType(AppSelect<String>));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNothing);
  });
}
