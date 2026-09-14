import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';
import 'package:petcare/features/benefits/benefits_pdf.dart';
import 'widget_test.dart' show FakeApi, showCare, tapVisible;

class BenefitsApi extends FakeApi {
  bool failLoad = false;
  final annualRequests = <String>[];
  final benefit = <String, dynamic>{
    'tier': 'PREVIEW',
    'usedBytes': 10485760,
    'limitBytes': 1073741824,
    'baseLimitBytes': 104857600,
    'photoCount': 8,
    'billingEnabled': false,
    'canExport': true,
    'canReport': true,
  };
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/benefits') {
      if (failLoad) {
        failLoad = false;
        throw const ApiError(503, 'UNAVAILABLE');
      }
      return benefit;
    }
    if (path.startsWith('/benefits/annual')) {
      annualRequests.add(path);
      return annualFixture;
    }
    return super.request(method, path, body);
  }
}

final annualFixture = <String, dynamic>{
  'year': 2025,
  'zoneId': 'Asia/Shanghai',
  'careCount': 3,
  'memoryCount': 2,
  'activeDays': 2,
  'caregiverCount': 1,
  'monthlyCare': [1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'monthlyMemories': [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'pets': [
    {
      'id': 'pet',
      'name': '豆包',
      'birthDate': '2024-02-29',
      'careCount': 3,
      'memoryCount': 2
    }
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('family benefits loads real capacity and opens annual report',
      (tester) async {
    final api = BenefitsApi()..failLoad = true;
    await showCare(tester, api);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('household-benefits')));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('10.0 MB / 1.0 GB'), findsOneWidget);
    expect(
        find.text(
            'Benefits preview · Free to try. No payment method required.'),
        findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('open-annual-report')));
    expect(find.text('3 care tasks · 2 memories'), findsOneWidget);
    expect(api.annualRequests.single, contains('zoneId=Asia%2FShanghai'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'base household has storage access without enabled premium actions',
      (tester) async {
    final api = BenefitsApi();
    api.benefit
        .addAll({'tier': 'FREE', 'canExport': false, 'canReport': false});
    await showCare(tester, api);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('household-benefits')));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('export-memory-book')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('export-memory-book')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'Chinese memory PDF handles a long story and six images; annual PDF is generated',
      () async {
    final font = await BenefitsPdf.fontData();
    final photo = base64Encode(
        File('assets/images/petcare_cat_cover.jpg').readAsBytesSync());
    final book = MemoryBookPdf(pet: {
      'name': '豆包',
      'photos': [photo]
    }, total: 1, font: font);
    book.addMemory({
      'id': 'memory',
      'title': '我们一起走过的日子',
      'story': List.filled(200, '今天一起去散步，看到了温暖的阳光。').join(),
      'author': '妈妈',
      'happenedOn': '2025-02-01',
      'createdAt': '2025-02-01T08:00:00Z',
      'photos': List.filled(6, photo)
    });
    final memoryPdf = await book.save();
    final annualPdf = await BenefitsPdf.annual(annualFixture);
    expect(ascii.decode(memoryPdf.take(5).toList()), '%PDF-');
    expect(ascii.decode(annualPdf.take(5).toList()), '%PDF-');
    final output = Platform.environment['PETCARE_PDF_QA'];
    if (output != null) {
      Directory(output).createSync(recursive: true);
      File('$output/memory-book.pdf').writeAsBytesSync(memoryPdf);
      File('$output/annual-report.pdf').writeAsBytesSync(annualPdf);
    }
  });
}
