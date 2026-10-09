import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/config/app_features.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/auth/auth_panel.dart';

class AuthFake extends CareApi {
  int registrations = 0, codeRequests = 0;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/auth/register/request') {
      codeRequests++;
      return null;
    }
    throw StateError('Unexpected request');
  }

  @override
  Future<void> registerVerified(
      String email, String password, String name, String code) async {
    registrations++;
    token = 'registered';
  }

  @override
  Future<void> login(String email, String password) async {
    throw const ApiError(401, 'REQUEST_FAILED');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'registration rejects malformed email and clears error after correction',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = AuthFake();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuthPanel(
                api: api, binding: true, onAuthenticated: () async {}))));
    expect(find.textContaining('Email verification is required to register.'),
        findsOneWidget);
    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.enterText(emailField, 'not-an-email');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address, e.g. name@example.com'),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'password-test-123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email verification code'),
        'test-code');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'password-test-123');
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 0);
    await tester.enterText(emailField, 'alex@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address, e.g. name@example.com'),
        findsNothing);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 1);
  });
  testWidgets('registration validates confirmation before submitting',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    // An empty nickname is now valid: the server generates a regional name.
    expect(find.text('Caregiver name (optional)'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'password-test-123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email verification code'),
        'test-code');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'different-password');
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 0);
    expect(find.text('Passwords do not match'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email verification code'),
        'test-code');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'password-test-123');
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 1);
    expect(authenticated, true);
    expect(
        find.textContaining('Change your nickname in Family'), findsOneWidget);
  });
  testWidgets('registration requires a code and throttles resend',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = AuthFake();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuthPanel(
                api: api, binding: true, onAuthenticated: () async {}))));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'password-test-123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'password-test-123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(api.registrations, 0);
    expect(find.text('Request and enter the email verification code'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Send verification code'));
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(api.codeRequests, 1);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Resend in 60 seconds'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('incorrect credentials remain on the login form', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var authenticated = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuthPanel(
                api: AuthFake(),
                onAuthenticated: () async {
                  authenticated = true;
                }))));
    expect(find.text('Forgot password?'),
        AppFeatures.emailActionsEnabled ? findsOneWidget : findsNothing);
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
