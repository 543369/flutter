import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

class ProfileApi extends FakeApi {
  final profile = <String, dynamic>{
    'id': 'account-1',
    'account': 'hello@example.com',
    'name': 'Sunny1234',
    'birthDate': '2000-02-29',
    'phone': null,
    'createdAt': '2026-09-15T01:00:00Z'
  };
  bool failSave = false;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/profile') {
      if (method == 'PATCH') {
        if (failSave) {
          failSave = false;
          throw const ApiError(503, 'UNAVAILABLE');
        }
        profile.addAll(body!);
      }
      return Map<String, dynamic>.from(profile);
    }
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets(
      'profile details, date picker, failed save retains edits and retry persists',
      (tester) async {
    final api = ProfileApi();
    await showCare(tester, api);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Personal profile'));
    expect(find.text('hello@example.com'), findsOneWidget);
    expect(find.text('2000-02-29'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2000/2/29'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Clover');
    await tester.enterText(find.byType(TextFormField).last, '+1 415 555 1234');
    api.failSave = true;
    await tapVisible(tester, find.text('Save profile'));
    expect(find.text('Clover'), findsOneWidget);
    await tapVisible(tester, find.text('Save profile'));
    expect(find.text('+1 415 555 1234'), findsOneWidget);
    expect(api.profile['name'], 'Clover');
    expect(api.profile['createdAt'], '2026-09-15T01:00:00Z');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
