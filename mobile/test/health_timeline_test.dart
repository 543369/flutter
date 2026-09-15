import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show showCare, tapVisible;
import 'health_family_test.dart' show HealthFamilyApi;
import 'health_export_test.dart' show exportSnapshot;

class TimelineApi extends HealthFamilyApi {
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path.startsWith('/pets/pet/health/timeline')) return exportSnapshot;
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets('health timeline opens, shows records and offers both formats',
      (tester) async {
    await showCare(tester, TimelineApi());
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pet-card-pet')));
    await tapVisible(tester, find.text('Health records'));
    await tester.tap(find.byTooltip('Timeline & export'));
    await tester.pumpAndSettle();
    expect(find.text('Health timeline & export'), findsOneWidget);
    expect(find.text('Preview PDF'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    await tapVisible(tester, find.text('疫苗记录'));
    expect(find.textContaining('详细信息见原始医嘱'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
