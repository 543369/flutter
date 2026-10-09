import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/auth/account_security_page.dart';

class SecurityFake extends CareApi {
  int changes = 0;
  bool reject = false, verified = true;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/auth/email/status') {
      return {
        'email': 'test@example.com',
        'verified': verified,
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
  testWidgets('unverified email blocks password change and opens verification',
      (tester) async {
    final api = SecurityFake()..verified = false;
    await tester.pumpWidget(MaterialApp(
        home: AccountSecurityPage(api: api, translate: (zh, en) => en)));
    await tester.pumpAndSettle();
    expect(find.text('Email not verified'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Change password'))
            .onPressed,
        isNull);
    for (final field
        in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.enabled, isFalse);
    }
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();
    expect(find.text('test@example.com'), findsWidgets);
    api.verified = true;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Email verified'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Change password'))
            .onPressed,
        isNotNull);
    expect(api.changes, 0);
  });
  for (final reject in [false, true]) {
    testWidgets('password validation and submission (rejected: $reject)',
        (tester) async {
      final api = SecurityFake()..reject = reject;
      await tester.pumpWidget(MaterialApp(
          home: AccountSecurityPage(api: api, translate: (zh, en) => en)));
      await tester.pumpAndSettle();
      expect(find.text('Verify email'), findsOneWidget);
      expect(find.text('Email verified'), findsOneWidget);
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
