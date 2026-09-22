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
    if (path == '/auth/email/status') {
      return {'email': 'owner@example.com', 'verified': false};
    }
    return null;
  }
}

void main() {
  testWidgets('verification shows recipient, cooldown and completion',
      (tester) async {
    final api = EmailFake();
    await tester.pumpWidget(MaterialApp(home: EmailActionPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.com'), findsOneWidget);
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Resend in 60s'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Resend in 60s'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'verification-code');
    final verifyButton = find.widgetWithText(FilledButton, 'Verify email');
    await tester.ensureVisible(verifyButton);
    await tester.tap(verifyButton);
    await tester.pumpAndSettle();
    expect(find.text('Email verified.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(api.calls.where((path) => path == '/auth/email/confirm').length, 1);
    await tester.pumpWidget(const SizedBox());
  });
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
    await tester.ensureVisible(find.text('Reset password'));
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(api.calls.length, 1);
    await tester.enterText(fields.at(3), 'New-password-42');
    await tester.ensureVisible(find.text('Reset password'));
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(api.calls.last, '/auth/recovery/confirm');
    expect(find.text('Password reset. Return to sign in.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Return to sign in'), findsOneWidget);
  });
}
