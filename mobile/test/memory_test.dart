import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/pets/memory_pages.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

const testPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=';

class MemoryApi extends FakeApi {
  final memories = <Map<String, dynamic>>[];
  int sequence = 0;
  @override
  Future<Map<String, dynamic>> dashboard() async => {
        ...await super.dashboard(),
        'pets': petItems
            .map((pet) => {
                  ...pet,
                  'memoryCount':
                      memories.where((m) => m['petId'] == pet['id']).length,
                })
            .toList(),
        'memberProfiles': [
          {'name': 'Alex', 'isMe': true},
          {'name': 'Sam', 'isMe': false},
        ],
      };

  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/invites') return {'code': 'TEST-CODE'};
    if (!path.contains('/memories')) return super.request(method, path, body);
    if (failNextSave && (method == 'POST' || method == 'PATCH')) {
      failNextSave = false;
      throw const ApiError(503, 'TEST_UNAVAILABLE');
    }
    final uri = Uri.parse(path);
    if (method == 'GET' && uri.pathSegments.length == 3) {
      return {
        'items': memories
            .map((m) => {
                  ...m,
                  'photoCount': (m['photos'] as List).length,
                  'coverData': (m['photos'] as List).firstOrNull,
                })
            .toList(),
        'total': memories.length,
        'hasMore': false,
      };
    }
    if (method == 'POST') {
      final id = 'memory-${sequence++}';
      memories.add({
        ...body!,
        'id': id,
        'petId': uri.pathSegments[1],
        'author': 'Alex',
        'createdAt': '2026-01-01T10:00:00Z'
      });
      return {'id': id};
    }
    final memory = memories.firstWhere((m) => m['id'] == uri.pathSegments.last);
    if (method == 'GET') return Map<String, dynamic>.from(memory);
    if (method == 'PATCH') {
      memory.addAll(body!);
      return {'id': memory['id']};
    }
    if (method == 'DELETE') {
      memories.remove(memory);
      return null;
    }
    throw StateError('Unexpected memory request: $method $path');
  }
}

void main() {
  testWidgets('pet card opens profile and memoir create edit delete flow',
      (tester) async {
    final api = MemoryApi();
    await showCare(tester, api);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pet-card-pet')));
    await tapVisible(tester, find.text('Their memory book'));
    await tapVisible(tester, find.byKey(const ValueKey('create-memory')));
    await tester.enterText(
        find.byKey(const ValueKey('memory-title')), 'First hello');
    await tester.enterText(
        find.byKey(const ValueKey('memory-story')), 'We brought Mochi home.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save memory'));
    await tester.pumpAndSettle();
    expect(find.text('Memory details'), findsOneWidget);
    expect(find.text('We brought Mochi home.'), findsOneWidget);
    final created = api.memories.single['createdAt'];
    await tester.tap(find.byTooltip('Edit memory'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('memory-story')), 'A very happy day.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save memory'));
    await tester.pumpAndSettle();
    expect(find.text('A very happy day.'), findsOneWidget);
    expect(api.memories.single['createdAt'], created);
    await tapVisible(tester, find.text('Delete memory'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.memories, isEmpty);
    expect(find.text('0 moments to keep'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'photo attachment and story survive save failure and allow removal',
      (tester) async {
    final api = MemoryApi()..failNextSave = true;
    await showCare(tester, api);
    final home = tester.state<CareHomeState>(find.byType(CareHome));
    showDialog<String>(
        context: home.context,
        builder: (_) => MemoryEditor(
            home: home, petId: 'pet', photoPicker: () async => testPhoto));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('memory-title')), 'Sunshine');
    await tester.enterText(
        find.byKey(const ValueKey('memory-story')), 'Sleeping by the window.');
    await tapVisible(tester, find.text('Add photo'));
    await tapVisible(tester, find.text('Add photo'));
    expect(find.text('Photos · 2/6'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Remove photo').first);
    expect(find.text('Photos · 1/6'), findsOneWidget);
    await tester.tap(find.text('Save memory'));
    await tester.pumpAndSettle();
    expect(api.memories, isEmpty);
    expect(find.text('Sleeping by the window.'), findsOneWidget);
    expect(find.text('Photos · 1/6'), findsOneWidget);
    await tester.tap(find.text('Save memory'));
    await tester.pumpAndSettle();
    expect(api.memories.single['photos'], [testPhoto]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [393.0, 800.0]) {
    testWidgets('family members and invitation work at width $width',
        (tester) async {
      await showCare(tester, MemoryApi());
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Sam'), findsOneWidget);
      await tapVisible(tester, find.text('Invite family'));
      expect(find.text('TEST-CODE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
