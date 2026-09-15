import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/home_shell.dart';
import '../benefits/benefits_page.dart';
import 'health_export.dart';

class HealthTimelinePage extends StatefulWidget {
  const HealthTimelinePage(
      {super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  @override
  State<HealthTimelinePage> createState() => _HealthTimelinePageState();
}

class _HealthTimelinePageState extends State<HealthTimelinePage> {
  Map<String, dynamic>? snapshot;
  DateTimeRange? range;
  String? error;
  bool loading = false, exporting = false;
  String purpose = 'vet';
  String t(String z, String e) => widget.home.t(z, e);
  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get period => range == null
      ? t('全部记录', 'All records')
      : '${day(range!.start)} – ${day(range!.end)}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
      snapshot = null;
    });
    try {
      final data = await widget.home.widget.api.request('GET',
          '/pets/${widget.petId}/health/timeline${range == null ? '' : '?from=${day(range!.start)}&to=${day(range!.end)}'}');
      if (mounted) {
        setState(() => snapshot = Map<String, dynamic>.from(data as Map));
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseRange() async {
    final result = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        initialDateRange: range);
    if (result != null && mounted) {
      setState(() => range = result);
      await load();
    }
  }

  Future<void> export(bool pdf) async {
    if (exporting || snapshot == null) return;
    final data = snapshot!;
    setState(() {
      exporting = true;
      error = null;
    });
    try {
      final filename = 'petcare-health-${widget.petId}.${pdf ? 'pdf' : 'csv'}';
      if (pdf) {
        final bytes = await HealthExport.pdf(data,
            purpose: purpose == 'vet' ? '就诊资料' : '寄养交接资料',
            period: range == null ? '全部记录' : period);
        if (!mounted) return;
        await Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) => BenefitPdfPreview(
                    bytes: bytes,
                    filename: filename,
                    title: t('健康时间线预览', 'Health timeline preview'))));
      } else {
        final bytes = HealthExport.csv(data);
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          final result = await getSaveLocation(
              suggestedName: filename,
              acceptedTypeGroups: [
                const XTypeGroup(label: 'CSV', extensions: [
                  'csv'
                ], uniformTypeIdentifiers: [
                  'public.comma-separated-values-text'
                ])
              ]);
          if (result == null) return;
          await XFile.fromData(bytes, name: filename, mimeType: 'text/csv')
              .saveTo(result.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('CSV 已保存', 'CSV saved'))));
          }
        } else {
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox;
          await SharePlus.instance.share(ShareParams(files: [
            XFile.fromData(bytes, name: filename, mimeType: 'text/csv')
          ], fileNameOverrides: [
            filename
          ], sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = t('导出未完成，请重试。', 'Export did not finish. Please retry.'));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = snapshot?['items'] as List? ?? [];
    return Scaffold(
        appBar: AppBar(title: Text(t('健康时间线与导出', 'Health timeline & export'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: const Color(0xffe5eee2),
                          borderRadius: BorderRadius.circular(26)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.timeline, size: 36),
                            const SizedBox(height: 12),
                            Text(
                                t('就诊前，准备清楚。\n寄养时，交接安心。',
                                    'Ready for the vet.\nPrepared for a stay.'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 12),
                            Text(t('按发生日期从早到晚整理记录。不包含个人账号、手机号和附件图片；附件仅显示数量。',
                                'Records are ordered from oldest to newest. Account details, phone numbers and attachment images are excluded; attachment counts are included.')),
                          ])),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'vet',
                            label: Text(t('就诊', 'Vet visit')),
                            icon: const Icon(Icons.local_hospital_outlined)),
                        ButtonSegment(
                            value: 'boarding',
                            label: Text(t('寄养', 'Boarding')),
                            icon: const Icon(Icons.home_outlined))
                      ],
                      selected: {
                        purpose
                      },
                      onSelectionChanged: exporting
                          ? null
                          : (v) => setState(() => purpose = v.first)),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                      onPressed: loading || exporting ? null : chooseRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(period)),
                  if (range != null)
                    TextButton(
                        onPressed: loading || exporting
                            ? null
                            : () {
                                setState(() => range = null);
                                load();
                              },
                        child: Text(t('恢复全部记录', 'Show all records'))),
                  if (range != null)
                    Text(t('仅包含所选日期范围，不等于完整健康史。',
                        'This date range may not include the full health history.')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    FilledButton.icon(
                        onPressed: loading || exporting || items.isEmpty
                            ? null
                            : () => export(true),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(t('预览 PDF', 'Preview PDF'))),
                    OutlinedButton.icon(
                        onPressed: loading || exporting || items.isEmpty
                            ? null
                            : () => export(false),
                        icon: const Icon(Icons.table_view_outlined),
                        label: Text(t('导出 CSV', 'Export CSV')))
                  ]),
                  if (loading || exporting)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: LinearProgressIndicator()),
                  if (error != null) ...[
                    Text(error!),
                    TextButton(
                        onPressed: loading || exporting ? null : load,
                        child: Text(t('重试', 'Retry')))
                  ],
                  const SizedBox(height: 22),
                  Text(
                      '${snapshot?['pet']?['name'] ?? ''} · ${items.length} ${t('条记录', 'records')}',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (!loading && snapshot != null && items.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(t(
                            '这个范围内还没有记录。', 'No records in this date range.'))),
                  for (final item in items)
                    Card(
                        color: const Color(0xfffaf1e5),
                        child: ExpansionTile(
                            leading: const Icon(Icons.radio_button_checked,
                                size: 18, color: Color(0xff668066)),
                            title: Text(
                                '${item['happenedOn']} · ${healthExportKinds[item['kind']]}'),
                            subtitle: Text(item['title'] as String),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (item['weightKg'] != null)
                                Text('${item['weightKg']} kg'),
                              SelectableText((item['notes'] as String).isEmpty
                                  ? t('未填写说明', 'No notes')
                                  : item['notes'] as String),
                              const SizedBox(height: 10),
                              Text(t('附件 ${item['attachmentCount']} 张（文件不包含图片）',
                                  '${item['attachmentCount']} attachments (images excluded from export)')),
                            ])),
                ]))));
  }
}
