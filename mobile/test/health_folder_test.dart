import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/app/home_shell.dart';
import 'package:petcare/features/health/health_pages.dart';
import 'health_family_test.dart' show HealthFamilyApi;
import 'widget_test.dart' show showCare, tapVisible;

class FolderApi extends HealthFamilyApi {
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse(path);
    if (uri.path == '/pets/pet/health' && method == 'GET') {
      final params = uri.queryParameters;
      final matching = health
          .where((v) =>
              (params['kind'] == '' || v['kind'] == params['kind']) &&
              (!params.containsKey('folder') ||
                  v['folder'] == params['folder']))
          .toList();
      final counts = <String, int>{};
      for (final row in health) {
        final f = row['folder'] as String;
        counts[f] = (counts[f] ?? 0) + 1;
      }
      return {
        'items': matching,
        'total': matching.length,
        'hasMore': false,
        'advanced': true,
        'attachmentLimit': 12,
        'folders': [
          for (final e in counts.entries) {'name': e.key, 'count': e.value}
        ]
      };
    }
    if (uri.path == '/pets/pet/health/organize') {
      for (final row in health) {
        if ((body!['ids'] as List).contains(row['id'])) {
          row['folder'] = body['folder'];
        }
      }
      return {'count': (body!['ids'] as List).length};
    }
    return super.request(method, path, body);
  }
}

Future<void> openFolders(WidgetTester tester, FolderApi api) async {
  api.health.addAll([
    {
      'id': 'weight',
      'kind': 'WEIGHT',
      'title': 'Weight check',
      'notes': '',
      'weightKg': 4.5,
      'happenedOn': '2026-10-20',
      'folder': 'Annual & follow-up'
    },
    {
      'id': 'vaccine',
      'kind': 'VACCINE',
      'title': 'Vaccination check',
      'notes': '',
      'weightKg': null,
      'happenedOn': '2026-10-20',
      'folder': 'Annual & follow-up'
    },
    {
      'id': 'visit',
      'kind': 'VISIT',
      'title': 'Unfiled visit',
      'notes': '',
      'weightKg': null,
      'happenedOn': '2026-10-20',
      'folder': ''
    },
  ]);
  await showCare(tester, api);
  final home = tester.state<CareHomeState>(find.byType(CareHome));
  Navigator.of(home.context).push(MaterialPageRoute<void>(
      builder: (_) => HealthRecordsPage(home: home, petId: 'pet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'folder opens mixed categories and combines with category filtering',
      (tester) async {
    await openFolders(tester, FolderApi());
    await tester.tap(find.text('Folder: All records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annual & follow-up'));
    await tester.pumpAndSettle();
    expect(find.text('Weight check'), findsOneWidget);
    expect(find.text('Vaccination check'), findsOneWidget);
    expect(find.text('Unfiled visit'), findsNothing);
    await tester.tap(find.text('Vaccines'));
    await tester.pumpAndSettle();
    expect(find.text('Weight check'), findsNothing);
    expect(find.text('Vaccination check'), findsOneWidget);
    await tester.tap(find.text('Folder: Annual & follow-up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfiled'));
    await tester.pumpAndSettle();
    expect(find.text('Unfiled visit'), findsOneWidget);
    expect(find.text('Vaccination check'), findsNothing);
  });
  testWidgets(
      'removing folder membership refreshes the open folder and preserves category',
      (tester) async {
    final api = FolderApi();
    await openFolders(tester, api);
    await tester.tap(find.text('Folder: All records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annual & follow-up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Organize 1'));
    expect(find.text('Organize into a folder'), findsOneWidget);
    await tester.tap(find.text('Save folder'));
    await tester.pumpAndSettle();
    expect(find.text('Weight check'), findsNothing);
    expect(api.health.first['kind'], 'WEIGHT');
    expect(api.health.first['folder'], '');
  });
}
