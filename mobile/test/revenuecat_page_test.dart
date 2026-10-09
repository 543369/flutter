import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/benefits/revenuecat_page.dart';

class NoBillingApi extends CareApi {
  int calls = 0;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    calls++;
    throw StateError('Unconfigured builds must not contact billing');
  }
}

void main() {
  testWidgets('unconfigured distribution cannot buy or restore',
      (tester) async {
    final api = NoBillingApi();
    await tester.pumpWidget(
        MaterialApp(home: RevenueCatPage(api: api, translate: (zh, en) => en)));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Membership purchases are unavailable. Please try again later.'),
        findsOneWidget);
    expect(find.text('Subscribe with Google Play'), findsNothing);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Restore purchases'))
            .onPressed,
        isNull);
    expect(api.calls, 0);
  });
}
