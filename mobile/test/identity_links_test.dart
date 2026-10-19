import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/auth/change_email_page.dart';
import 'package:petcare/features/auth/account_security_page.dart';

class LinksApi extends CareApi {
  final calls = <String>[];
  bool linked = false, rejectCode = false;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    calls.add(path);
    if (path == '/auth/email/status') {
      return {
        'email': 'old@example.com',
        'verified': true,
        'hasPassword': true,
        'appleLinked': linked
      };
    }
    if (path == '/auth/sessions') return [];
    if (path == '/auth/email/change/request') {
      expect(body,
          {'email': 'new@example.com', 'password': 'Original-password-42'});
      return null;
    }
    if (path == '/auth/email/change/confirm') {
      if (rejectCode) throw const ApiError(400, 'EMAIL_CHANGE_INVALID');
      expect(body, {'code': 'new-email-proof'});
      return null;
    }
    if (path == '/auth/apple/link/challenge') {
      expect(body, {'password': 'Original-password-42'});
      return {'nonce': 'account-bound-nonce'};
    }
    if (path == '/auth/apple/link') {
      expect(body,
          {'identityToken': 'apple-proof', 'nonce': 'account-bound-nonce'});
      linked = true;
      return null;
    }
    throw StateError(path);
  }
}

void main() {
  testWidgets(
      'email change validates input and keeps invalid code available for retry',
      (tester) async {
    final api = LinksApi()..rejectCode = true;
    await tester.pumpWidget(
        MaterialApp(home: ChangeEmailPage(api: api, translate: (z, e) => e)));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    await tester.enterText(find.byType(TextField).at(0), 'new@example.com');
    await tester.enterText(
        find.byType(TextField).at(1), 'Original-password-42');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Code sent to new@example.com'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).enabled, false);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        isEmpty);
    await tester.enterText(find.byType(TextField).at(2), 'new-email-proof');
    await tester.ensureVisible(find.text('Confirm email change'));
    await tester.tap(find.text('Confirm email change'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('The code is invalid or expired'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
        'new-email-proof');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Apple linking uses password-bound challenge and preserves account session',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('petcare/apple');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      expect(call.method, 'signIn');
      expect(call.arguments, 'account-bound-nonce');
      return 'apple-proof';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final api = LinksApi()..token = 'same-session';
    await tester.pumpWidget(MaterialApp(
        home: AccountSecurityPage(api: api, translate: (z, e) => e)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Apple sign-in'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Apple sign-in'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Original-password-42');
    await tester.pump();
    await tester.tap(find.text('Continue linking'));
    await tester.pumpAndSettle();
    expect(api.linked, true);
    expect(api.token, 'same-session');
    expect(find.text('Linked to this account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
