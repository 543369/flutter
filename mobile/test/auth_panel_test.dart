import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/auth/auth_panel.dart';

class AuthFake extends CareApi {
  int registrations = 0;
  @override
  Future<void> register(String email, String password, String name) async {
    registrations++;
    token = 'registered';
  }

  @override
  Future<void> login(String email, String password) async {
    throw const ApiError(401, 'REQUEST_FAILED');
  }
}

void main() {
  testWidgets('registration validates confirmation before submitting',
      (tester) async {
    final api = AuthFake();
    var authenticated = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuthPanel(
                api: api,
                onAuthenticated: () async {
                  authenticated = true;
                }))));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Caregiver name'), 'Alex');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'password-test-123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'different-password');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 0);
    expect(find.text('Passwords do not match'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'password-test-123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 1);
    expect(authenticated, true);
  });
  testWidgets('incorrect credentials remain on the login form', (tester) async {
    var authenticated = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuthPanel(
                api: AuthFake(),
                onAuthenticated: () async {
                  authenticated = true;
                }))));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(authenticated, false);
    expect(find.textContaining('Incorrect email or password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
