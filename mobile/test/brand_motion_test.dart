import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/widgets/brand_motion.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('loading delays the mark and cancels pending work on dispose', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PawLoading()));
    expect(find.byType(PawMark), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PawMark), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion leaves loading visible without an active ticker',
    (tester) async {
      await tester.pumpWidget(host(const PawLoading(), reduced: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(PawMark), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('outgoing content cannot receive taps during a transition', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        GentleSwitch(
          child: TextButton(
            key: const ValueKey('old'),
            onPressed: () => taps++,
            child: const Text('Old action'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      host(
        const GentleSwitch(
          child: SizedBox(key: ValueKey('new'), width: 100, height: 50),
        ),
      ),
    );
    await tester.tap(find.text('Old action'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpAndSettle();
    expect(find.text('Old action'), findsNothing);
  });
}
