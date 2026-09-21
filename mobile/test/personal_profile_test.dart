import 'dart:convert';
import 'package:image/image.dart' as image_lib;
// The picker interface is supplied by the app's image_picker dependency.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:petcare/features/family/member_avatar.dart';
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
    if (path == '/profile/avatar' && method == 'PUT') {
      if (failSave) {
        failSave = false;
        throw const ApiError(503, 'UNAVAILABLE');
      }
      profile.addAll(body!);
      return Map<String, dynamic>.from(profile);
    }
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

class AvatarPicker extends ImagePickerPlatform {
  XFile? selection;
  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      selection;
}

void main() {
  testWidgets(
      'avatar cancellation, failed upload and retry preserve saved profile',
      (tester) async {
    final previous = ImagePickerPlatform.instance;
    final picker = AvatarPicker();
    ImagePickerPlatform.instance = picker;
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final api = ProfileApi();
    await showCare(tester, api);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Personal profile'));
    await tester.tap(find.text('Change avatar'));
    await tester.pumpAndSettle();
    expect(api.profile['avatarData'], isNull);
    picker.selection = XFile.fromData(
        image_lib.encodePng(image_lib.Image(width: 600, height: 300)),
        mimeType: 'image/png');
    api.failSave = true;
    await tester.tap(find.text('Change avatar'));
    await tester.pumpAndSettle();
    expect(api.profile['avatarData'], isNull);
    expect(
        find.text(
            'Could not upload your avatar. Choose an image and try again.'),
        findsOneWidget);
    await tester.tap(find.text('Change avatar'));
    await tester.pumpAndSettle();
    final encoded = api.profile['avatarData'] as String;
    final decoded = image_lib.decodeImage(base64Decode(encoded))!;
    expect(decoded.width, 256);
    expect(decoded.height, 256);
    expect(tester.widget<MemberAvatar>(find.byType(MemberAvatar).last).data,
        encoded);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Personal profile'));
    expect(tester.widget<MemberAvatar>(find.byType(MemberAvatar).last).data,
        encoded);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
