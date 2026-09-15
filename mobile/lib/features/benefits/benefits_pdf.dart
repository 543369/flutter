import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../pets/pet_profile.dart';

class BenefitsPdf {
  static Future<ByteData> fontData() =>
      rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
  static pw.ThemeData theme(ByteData data) {
    final font = pw.Font.ttf(data);
    return pw.ThemeData.withFont(
        base: font, bold: font, italic: font, boldItalic: font);
  }

  static final brown = PdfColor.fromHex('#5B3B2E');
  static final cream = PdfColor.fromHex('#FFF0DB');
  static pw.Widget footer(pw.Context context) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('爪伴 PetCare · 把陪伴好好收藏',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('${context.pageNumber}',
                style: const pw.TextStyle(fontSize: 9)),
          ]));

  static Future<Uint8List> annual(Map<String, dynamic> report) async {
    final document =
        pw.Document(title: '${report['year']} 年度成长报告', author: 'PetCare');
    final year = report['year'] as int;
    final now = DateTime.now();
    final ageAt = year == now.year ? now : DateTime(year, 12, 31);
    document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme(await fontData()),
        margin: const pw.EdgeInsets.all(36),
        footer: footer,
        build: (_) => [
              pw.Text('$year', style: pw.TextStyle(fontSize: 46, color: brown)),
              pw.Text('这一年，我们一起长大',
                  style: pw.TextStyle(fontSize: 25, color: brown)),
              pw.SizedBox(height: 12),
              pw.Text('家庭年度成长报告 · ${report['zoneId']}'),
              pw.SizedBox(height: 24),
              pw.Container(
                  color: cream,
                  padding: const pw.EdgeInsets.all(18),
                  child: pw.Text(
                      '${report['careCount']} 次照护  ·  ${report['memoryCount']} 篇回忆\n'
                      '${report['activeDays']} 个照护日  ·  ${report['caregiverCount']} 位记录照护的家人',
                      style: const pw.TextStyle(fontSize: 16, lineSpacing: 8))),
              pw.SizedBox(height: 22),
              pw.Text('每个月的小日常',
                  style: pw.TextStyle(fontSize: 18, color: brown)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                  headers: ['月份', '照护次数', '回忆篇数'],
                  data: List.generate(
                      12,
                      (i) => [
                            '${i + 1} 月',
                            '${report['monthlyCare'][i]}',
                            '${report['monthlyMemories'][i]}'
                          ]),
                  headerDecoration: pw.BoxDecoration(color: cream),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  headerStyle: const pw.TextStyle(fontSize: 11),
                  cellPadding: const pw.EdgeInsets.all(5)),
              pw.SizedBox(height: 22),
              pw.Text('小伙伴的成长档案',
                  style: pw.TextStyle(fontSize: 18, color: brown)),
              for (final pet in report['pets'] as List) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                    '${pet['name']} · ${petAgeLabel(pet['birthDate'], ageAt, chinese: true)}',
                    style: const pw.TextStyle(fontSize: 15)),
                pw.Text(
                    '生日：${pet['birthDate'] ?? '未填写'} · ${pet['careCount']} 次照护 · ${pet['memoryCount']} 篇回忆'),
              ],
              pw.SizedBox(height: 20),
              pw.Text('统计依据家庭当前保留的记录；照护按年末状态去重，撤销后重新完成不会重复累计。当前年份统计截至导出时。',
                  style: const pw.TextStyle(fontSize: 10)),
            ]));
    return document.save();
  }
}

enum MemoryBookTemplate { warm, botanical, editorial }

/// Each template changes both the palette and the photo layout.
class MemoryBookPdf {
  MemoryBookPdf(
      {required this.pet,
      required this.total,
      required ByteData font,
      this.template = MemoryBookTemplate.warm})
      : document = pw.Document(title: '${pet['name']}的回忆录', author: 'PetCare'),
        theme = BenefitsPdf.theme(font) {
    document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: pw.EdgeInsets.all(
            template == MemoryBookTemplate.editorial ? 26 : 38),
        footer: BenefitsPdf.footer,
        build: (_) => [
              pw.Container(
                  width: double.infinity,
                  color: paper,
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            template == MemoryBookTemplate.editorial
                                ? 'THE PET JOURNAL'
                                : 'PETCARE / OUR LITTLE DAYS',
                            style: pw.TextStyle(
                                fontSize: 10, color: ink, letterSpacing: 2)),
                        pw.SizedBox(height: 22),
                        pw.Text('和${pet['name']}的故事',
                            style: pw.TextStyle(
                                fontSize:
                                    template == MemoryBookTemplate.editorial
                                        ? 36
                                        : 28,
                                color: ink)),
                        pw.SizedBox(height: 16),
                        pw.Text('$total 篇回忆 · 一起走过的日子',
                            style: pw.TextStyle(color: ink)),
                      ])),
              pw.SizedBox(height: 24),
              if (petPhotos(pet).isNotEmpty)
                photo(petPhotos(pet).first,
                    height:
                        template == MemoryBookTemplate.editorial ? 350 : 280),
              pw.SizedBox(height: 24),
              pw.Text(
                  (pet['biography'] as String? ?? '').isEmpty
                      ? '每一件小事，都值得好好珍藏。'
                      : pet['biography'] as String,
                  overflow: pw.TextOverflow.span,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 4)),
            ]));
  }
  final Map<String, dynamic> pet;
  final int total;
  final pw.Document document;
  final pw.ThemeData theme;
  final MemoryBookTemplate template;
  PdfColor get ink => PdfColor.fromHex(switch (template) {
        MemoryBookTemplate.warm => '#76503A',
        MemoryBookTemplate.botanical => '#426451',
        MemoryBookTemplate.editorial => '#24384C'
      });
  PdfColor get paper => PdfColor.fromHex(switch (template) {
        MemoryBookTemplate.warm => '#FFF0DC',
        MemoryBookTemplate.botanical => '#EAF0E5',
        MemoryBookTemplate.editorial => '#E7EDF3'
      });
  static pw.Widget photo(String data, {double height = 260}) {
    try {
      return pw.Container(
          height: height,
          alignment: pw.Alignment.center,
          child: pw.Image(pw.MemoryImage(base64Decode(data)),
              fit: pw.BoxFit.contain));
    } catch (_) {
      return pw.Text('此照片无法读取');
    }
  }

  List<pw.Widget> pictures(List photos) {
    if (template == MemoryBookTemplate.botanical) {
      return [
        for (var i = 0; i < photos.length; i += 2)
          pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Row(children: [
                for (var j = i; j < i + 2; j++)
                  pw.Expanded(
                      child: pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: j < photos.length
                              ? photo(photos[j] as String, height: 200)
                              : pw.SizedBox(height: 200))),
              ]))
      ];
    }
    return [
      for (final value in photos)
        pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 18),
            child: template == MemoryBookTemplate.warm
                ? pw.Container(
                    color: paper,
                    padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 24),
                    child: photo(value as String, height: 230))
                : photo(value as String, height: 350))
    ];
  }

  void addMemory(Map<String, dynamic> memory) {
    document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: pw.EdgeInsets.all(
            template == MemoryBookTemplate.editorial ? 26 : 38),
        maxPages: 40,
        footer: BenefitsPdf.footer,
        build: (_) => [
              pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  color: paper,
                  child: pw.Text(
                      '${memory['happenedOn']}  /  ${template == MemoryBookTemplate.botanical ? '生长的日常' : template == MemoryBookTemplate.editorial ? 'LIFE WITH YOU' : '温暖的一页'}',
                      style: pw.TextStyle(color: ink, fontSize: 12))),
              pw.SizedBox(height: 20),
              pw.Text(memory['title'] as String,
                  style: pw.TextStyle(fontSize: 26, color: ink)),
              pw.SizedBox(height: 12),
              pw.Text('由 ${memory['author'] ?? '家人'} 记录',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 20),
              pw.Text(memory['story'] as String,
                  overflow: pw.TextOverflow.span,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 6)),
              pw.SizedBox(height: 22),
              ...pictures(memory['photos'] as List),
              pw.Text('创建时间：${memory['createdAt']}',
                  style: const pw.TextStyle(fontSize: 9)),
            ]));
  }

  Future<Uint8List> save() => document.save();
}
