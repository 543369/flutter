import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../benefits/benefits_pdf.dart';

const healthExportKinds = {
  'VACCINE': '疫苗',
  'DEWORMING': '驱虫',
  'MEDICATION': '用药',
  'ALLERGY': '过敏',
  'WEIGHT': '体重',
  'VISIT': '就诊'
};

class HealthExport {
  static String cell(Object? value) {
    var text = value?.toString() ?? '';
    // Prevent user-entered notes/names from becoming spreadsheet formulas.
    if (RegExp(r'^[\s]*[=+@-]|^[\t\r\n]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  static Uint8List csv(Map<String, dynamic> snapshot) {
    final pet = snapshot['pet'] as Map;
    final rows = <List<Object?>>[
      [
        '宠物',
        '种类',
        '生日',
        '发生日期',
        '类型',
        '标题',
        '详细说明',
        '体重(kg)',
        '附件数量（文件未包含）',
        '文件夹',
        '记录ID',
        '创建时间',
        '更新时间',
        '生成时间'
      ],
      for (final row in snapshot['items'] as List)
        [
          pet['name'],
          pet['species'],
          pet['birthDate'],
          row['happenedOn'],
          healthExportKinds[row['kind']],
          row['title'],
          row['notes'],
          row['weightKg'],
          row['attachmentCount'],
          row['folder'],
          row['id'],
          row['createdAt'],
          row['updatedAt'],
          snapshot['generatedAt']
        ],
    ];
    return Uint8List.fromList(utf8.encode(
        '\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n'));
  }

  static Future<Uint8List> pdf(Map<String, dynamic> snapshot,
      {required String purpose, required String period}) async {
    final theme = BenefitsPdf.theme(await BenefitsPdf.fontData());
    final doc = pw.Document(title: '健康档案 · $purpose', author: '爪伴 PetCare');
    final pet = snapshot['pet'] as Map;
    final rows = snapshot['items'] as List;
    final green = PdfColor.fromHex('#536D55'),
        light = PdfColor.fromHex('#EAF0E5');
    doc.addPage(pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        footer: BenefitsPdf.footer,
        build: (_) => [
              pw.Container(
                  width: double.infinity,
                  color: light,
                  padding: const pw.EdgeInsets.all(26),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PETCARE  /  HEALTH TIMELINE',
                            style: pw.TextStyle(fontSize: 10, color: green)),
                        pw.SizedBox(height: 18),
                        pw.Text(purpose,
                            style: pw.TextStyle(fontSize: 32, color: green)),
                        pw.SizedBox(height: 14),
                        pw.Text('${pet['name']} · 健康档案',
                            style: const pw.TextStyle(fontSize: 20))
                      ])),
              pw.SizedBox(height: 24),
              pw.Text('生日：${pet['birthDate'] ?? '未填写'}    ·    $period'),
              pw.SizedBox(height: 12),
              pw.Text('共 ${rows.length} 条记录 · 按发生日期从早到晚排列'),
              pw.SizedBox(height: 24),
              for (final entry in healthExportKinds.entries)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Text(
                        '${entry.value}：${rows.where((r) => r['kind'] == entry.key).length} 条记录')),
              pw.SizedBox(height: 22),
              pw.Text('交接说明', style: pw.TextStyle(fontSize: 18, color: green)),
              pw.SizedBox(height: 10),
              pw.Text(
                  '本文件整理主人录入的历史记录，不代表当前仍存在过敏或正在用药。请结合原始医嘱确认；附件仅列数量，图片文件未包含。',
                  overflow: pw.TextOverflow.span,
                  style: const pw.TextStyle(lineSpacing: 5)),
              pw.SizedBox(height: 16),
              pw.Text('不包含个人账号或手机号。生成时间：${snapshot['generatedAt']}',
                  style: const pw.TextStyle(fontSize: 10)),
            ]));
    // Short records share a page; long notes continue without truncation.
    doc.addPage(pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        maxPages: 10000,
        footer: BenefitsPdf.footer,
        build: (_) => [
              for (final row in rows) ...[
                pw.NewPage(freeSpace: 160),
                pw.Container(
                    width: double.infinity,
                    color: light,
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Text(
                        '${row['happenedOn']}  ·  ${healthExportKinds[row['kind']]}',
                        style: pw.TextStyle(fontSize: 15, color: green))),
                pw.SizedBox(height: 20),
                pw.Text(row['title'] as String,
                    style: pw.TextStyle(fontSize: 23, color: green)),
                if (row['weightKg'] != null) ...[
                  pw.SizedBox(height: 14),
                  pw.Text('${row['weightKg']} kg',
                      style: const pw.TextStyle(fontSize: 22))
                ],
                pw.SizedBox(height: 18),
                pw.Text(
                    (row['notes'] as String).isEmpty
                        ? '未填写详细说明'
                        : row['notes'] as String,
                    overflow: pw.TextOverflow.span,
                    style: const pw.TextStyle(fontSize: 12, lineSpacing: 5)),
                pw.SizedBox(height: 24),
                pw.Divider(color: light),
                pw.Text(
                    '附件：${row['attachmentCount']} 张（图片未包含） · 文件夹：${row['folder'] == '' ? '未归档' : row['folder']}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Text('创建：${row['createdAt']}\n更新：${row['updatedAt']}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 24),
              ],
            ]));
    return doc.save();
  }
}
