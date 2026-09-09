import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/auth/email_action_page.dart';

class EmailFake extends CareApi {
  final calls = <String>[];
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    calls.add(path);
    return null;
  }
}

void main() {
  testWidgets(
      'recovery validates confirmation then submits code and clears password',
      (tester) async {
    final api = EmailFake();
    await tester.pumpWidget(
        MaterialApp(home: EmailActionPage(api: api, recovery: true)));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(api.calls, ['/auth/recovery/request']);
    await tester.enterText(fields.at(1), 'email-code');
    await tester.enterText(fields.at(2), 'New-password-42');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.calls.length, 1);
    await tester.enterText(fields.at(3), 'New-password-42');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.calls.last, '/auth/recovery/confirm');
    expect(find.text('Password reset. Return to sign in.'), findsOneWidget);
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, isEmpty);
  });
}
