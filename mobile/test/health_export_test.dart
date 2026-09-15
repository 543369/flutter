import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/features/health/health_export.dart';
import 'package:petcare/features/benefits/benefits_pdf.dart';

final exportSnapshot = <String, dynamic>{
  'pet': {
    'id': 'pet',
    'name': '豆包',
    'species': 'dog',
    'birthDate': '2024-02-29'
  },
  'generatedAt': '2026-09-15T08:00:00Z',
  'items': [
    for (final entry in healthExportKinds.entries)
      {
        'id': entry.key,
        'kind': entry.key,
        'happenedOn': '2026-09-01',
        'title': '${entry.value}记录',
        'notes': '今天的记录已整理好。\n详细信息见原始医嘱，交接时请再次确认。',
        'weightKg': entry.key == 'WEIGHT' ? 4.25 : null,
        'attachmentCount': 2,
        'folder': '日常记录',
        'createdAt': '2026-09-01T08:00:00Z',
        'updatedAt': '2026-09-01T08:00:00Z',
      }
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'CSV preserves Chinese, quotes and multiline notes, neutralizes formulas',
      () {
    expect(HealthExport.cell('=HYPERLINK("bad")'), '"\'=HYPERLINK(""bad"")"');
    expect(HealthExport.cell('  +cmd'), '"\'  +cmd"');
    expect(HealthExport.cell('a,b\n"c"'), '"a,b\n""c"""');
    final csv = utf8.decode(HealthExport.csv(exportSnapshot));
    expect(HealthExport.csv(exportSnapshot).take(3).toList(), [239, 187, 191]);
    expect(csv, contains('疫苗'));
    expect(csv, contains('体重(kg)'));
    expect(csv, isNot(contains('手机号')));
  });
  test('health PDF and three memory templates retain long text and six photos',
      () async {
    final photo = base64Encode(
        File('assets/images/petcare_cat_cover.jpg').readAsBytesSync());
    final font = await BenefitsPdf.fontData();
    final output = Platform.environment['PETCARE_EXPORT_QA'];
    if (output != null) Directory(output).createSync(recursive: true);
    for (final template in MemoryBookTemplate.values) {
      final book = MemoryBookPdf(pet: {
        'name': '豆包',
        'photos': [photo],
        'biography': '喜欢晒太阳，也喜欢陪你慢慢散步。'
      }, total: 1, font: font, template: template);
      book.addMemory({
        'happenedOn': '2026-09-01',
        'title': '阳光洒满窗台的午后',
        'author': '家人',
        'story': List.filled(100, '今天一起去散步，阳光暖暖的。').join(),
        'photos': List.filled(6, photo),
        'createdAt': '2026-09-01T08:00:00Z'
      });
      final bytes = await book.save();
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      if (output != null) {
        File('$output/memory-${template.name}.pdf').writeAsBytesSync(bytes);
      }
    }
    final pdf =
        await HealthExport.pdf(exportSnapshot, purpose: '就诊资料', period: '全部记录');
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
    if (output != null) {
      File('$output/health-timeline.pdf').writeAsBytesSync(pdf);
      File('$output/health-timeline.csv')
          .writeAsBytesSync(HealthExport.csv(exportSnapshot));
    }
  });
}
