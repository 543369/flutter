import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/auth/account_security_page.dart';

class SecurityFake extends CareApi {
  int changes = 0;
  bool reject = false;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/auth/email/status') {
      return {
        'email': 'test@example.com',
        'verified': false,
        'hasPassword': true
      };
    }
    if (path == '/auth/sessions') return <dynamic>[];
    changes++;
    if (reject) throw const ApiError(403, 'REQUEST_FAILED');
    return null;
  }
}

void main() {
  for (final reject in [false, true]) {
    testWidgets('password validation and submission (rejected: $reject)',
        (tester) async {
      final api = SecurityFake()..reject = reject;
      await tester.pumpWidget(MaterialApp(
          home: AccountSecurityPage(api: api, translate: (zh, en) => en)));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Original-password-42');
      await tester.enterText(fields.at(1), 'Changed-password-43');
      await tester.enterText(fields.at(2), 'Mismatch-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();
      expect(api.changes, 0);
      expect(find.text('Passwords do not match'), findsOneWidget);
      await tester.enterText(fields.at(2), 'Changed-password-43');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();
      expect(api.changes, 1);
      expect(find.byType(AccountSecurityPage), findsOneWidget);
      if (reject) {
        expect(find.text('Current password is incorrect'), findsOneWidget);
      } else {
        for (final field in tester.widgetList<TextFormField>(fields)) {
          expect(field.controller!.text, isEmpty);
        }
        expect(
            find.text('Password changed. Other sessions have been signed out.'),
            findsOneWidget);
      }
    });
  }
}
