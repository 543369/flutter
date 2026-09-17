import '../../core/theme/app_spacing.dart';
import '../family/household_management_pages.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../app/home_shell.dart';
import '../pets/pet_detail_page.dart';
import '../pets/pet_profile.dart';
import 'benefits_pdf.dart';

String storageLabel(num bytes) => bytes >= 1073741824
    ? '${(bytes / 1073741824).toStringAsFixed(1)} GB'
    : '${(bytes / 1048576).toStringAsFixed(1)} MB';

class BenefitsPage extends StatefulWidget {
  const BenefitsPage({super.key, required this.home, this.initialPetId});
  final CareHomeState home;
  final String? initialPetId;
  @override
  State<BenefitsPage> createState() => _BenefitsPageState();
}

class _BenefitsPageState extends State<BenefitsPage> {
  Map<String, dynamic>? status;
  String? error, petId;
  bool loading = true, exporting = false;
  int operation = 0;
  String progress = '';
  MemoryBookTemplate bookTemplate = MemoryBookTemplate.warm;
  String t(String zh, String en) => widget.home.t(zh, en);

  @override
  void initState() {
    super.initState();
    petId =
        widget.initialPetId ?? widget.home.pets.firstOrNull?['id'] as String?;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.home.widget.api.request('GET', '/benefits');
      if (mounted) {
        setState(() => status = Map<String, dynamic>.from(response as Map));
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> exportBook() async {
    if (exporting || petId == null) return;
    final pet = widget.home.pets.where((p) => p['id'] == petId).firstOrNull;
    if (pet == null) return;
    final token = ++operation;
    setState(() {
      exporting = true;
      error = null;
      progress = t('正在整理回忆…', 'Collecting memories…');
    });
    bool active() => mounted && operation == token;
    try {
      final font = await BenefitsPdf.fontData();
      if (!active()) return;
      MemoryBookPdf? book;
      var offset = 0;
      final seen = <String>{};
      while (true) {
        final page = await widget.home.widget.api
            .request('GET', '/benefits/memories/${pet['id']}?offset=$offset');
        if (!active()) return;
        book ??= MemoryBookPdf(
            pet: pet,
            total: page['total'] as int,
            font: font,
            template: bookTemplate);
        final items = page['items'] as List;
        if (items.isEmpty && offset == 0) {
          setState(() => error = t('还没有回忆。先到宠物档案写下第一篇故事吧。',
              'Write your first memory from the pet profile before exporting.'));
          return;
        }
        for (final raw in items) {
          final memory = Map<String, dynamic>.from(raw as Map);
          if (seen.add(memory['id'] as String)) book.addMemory(memory);
        }
        offset += items.length;
        setState(() => progress = t('已整理 ${seen.length} / ${page['total']} 篇回忆',
            '${seen.length} / ${page['total']} memories collected'));
        if (page['hasMore'] != true || items.isEmpty) break;
      }
      if (!active()) return;
      setState(() => progress = t('正在生成 PDF…', 'Creating PDF…'));
      final bytes = await book.save();
      if (!mounted || operation != token) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BenefitPdfPreview(
              bytes: bytes,
              filename: 'petcare-memories-${pet['id']}.pdf',
              title: t('${pet['name']}的回忆录', '${pet['name']} memories'))));
    } catch (e) {
      if (active()) {
        setState(() => error =
            t('导出未完成。', 'Export did not finish. ') + widget.home.message(e));
      }
    } finally {
      if (active()) setState(() => exporting = false);
    }
  }

  Widget panel(Color color, List<Widget> children) => Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  @override
  Widget build(BuildContext context) {
    final pets = widget.home.pets;
    final selected = pets.where((p) => p['id'] == petId).firstOrNull;
    final used = (status?['usedBytes'] as num? ?? 0).toDouble();
    final limit = (status?['limitBytes'] as num? ?? 1).toDouble();
    return Scaffold(
      appBar: AppBar(title: Text(t('家庭权益', 'Household benefits'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: AppSpacing.pageInsets, children: [
                if (loading) const LinearProgressIndicator(),
                if (error != null) ...[
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  if (status == null)
                    TextButton(onPressed: load, child: Text(t('重试', 'Retry'))),
                  const SizedBox(height: AppSpacing.content)
                ],
                if (status != null) ...[
                  panel(const Color(0xffffefcc), [
                    const Icon(Icons.auto_awesome_outlined,
                        size: 32, color: Color(0xffad6345)),
                    const SizedBox(height: AppSpacing.item),
                    Text(t('让陪伴，留得更久一点。', 'Keep your moments for longer.'),
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.inline),
                    Text(status!['tier'] == 'PREVIEW'
                        ? t('权益体验中 · 暂不收费，无需绑定支付方式。',
                            'Benefits preview · Free to try. No payment method required.')
                        : status!['tier'] == 'FAMILY'
                            ? t('家庭共享权益已启用', 'Shared family benefits enabled')
                            : t('基础空间 · 暂未开放扩展权益',
                                'Basic storage · Extended benefits are not enabled')),
                    if (status!['expiresAt'] != null)
                      Text(t('有效期至 ${status!['expiresAt']}',
                          'Available until ${status!['expiresAt']}')),
                  ]),
                  const SizedBox(height: AppSpacing.content),
                  panel(const Color(0xffe4eef6), [
                    Row(children: [
                      const Icon(Icons.photo_library_outlined),
                      const SizedBox(width: AppSpacing.inline),
                      Expanded(
                          child: Text(t('全家的照片空间', 'Your family photo storage'),
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          tooltip: t('刷新用量', 'Refresh storage'),
                          onPressed: loading ? null : load,
                          icon: const Icon(Icons.refresh))
                    ]),
                    const SizedBox(height: AppSpacing.item),
                    Text('${storageLabel(used)} / ${storageLabel(limit)}',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.item),
                    LinearProgressIndicator(
                        value: (used / limit).clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8)),
                    const SizedBox(height: AppSpacing.inline),
                    Text(t('共 ${status!['photoCount']} 张图片，包含健康附件。',
                        '${status!['photoCount']} images, including health attachments.')),
                    Text(t('宠物档案照片、回忆录照片和健康图片附件共用家庭空间。',
                        'Pet profile photos, memory photos and health image attachments share the same household storage.')),
                    if (limit > (status!['baseLimitBytes'] as num)) ...[
                      const SizedBox(height: AppSpacing.inline),
                      Text(t(
                          '基础 ${storageLabel(status!['baseLimitBytes'] as num)}，当前已扩容至 ${storageLabel(limit)}。',
                          'Expanded from ${storageLabel(status!['baseLimitBytes'] as num)} to ${storageLabel(limit)}.'))
                    ],
                    if (used >= limit) ...[
                      const SizedBox(height: AppSpacing.inline),
                      Text(t('空间已满。已有内容仍可查看，可删除不需要的照片或健康附件释放空间。',
                          'Storage is full. Existing content stays available; delete unwanted photos or health attachments to free space.'))
                    ],
                  ]),
                  const SizedBox(height: AppSpacing.content),
                  panel(const Color(0xffffeadf), [
                    Text(t('把回忆，装订成一本书', 'Your memories, made into a book'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.inline),
                    Text(t('故事、日期和照片一起导出，保存为 PDF，留给未来的自己。',
                        'Export stories, dates and photos as a PDF to keep.')),
                    const SizedBox(height: AppSpacing.content),
                    if (pets.isNotEmpty)
                      DropdownButtonFormField<String>(
                          borderRadius: BorderRadius.circular(16),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          elevation: 3,
                          icon: const Icon(Icons.expand_more_rounded, size: 20),
                          key: const ValueKey('benefit-pet'),
                          initialValue: selected?['id'] as String?,
                          decoration: InputDecoration(
                              labelText: t('选择小伙伴', 'Choose a pet')),
                          items: pets
                              .map((p) => DropdownMenuItem(
                                  value: p['id'] as String,
                                  child: Text(p['name'] as String)))
                              .toList(),
                          onChanged: exporting
                              ? null
                              : (value) => setState(() => petId = value)),
                    const SizedBox(height: AppSpacing.content),
                    Text(t('选择回忆录模板', 'Choose a book template')),
                    const SizedBox(height: AppSpacing.inline),
                    Wrap(
                        spacing: AppSpacing.inline,
                        runSpacing: AppSpacing.inline,
                        children: [
                          for (final style in MemoryBookTemplate.values)
                            SizedBox(
                                width: 100,
                                child: InkWell(
                                    key: ValueKey(
                                        'memory-template-${style.name}'),
                                    onTap: exporting
                                        ? null
                                        : () => setState(
                                            () => bookTemplate = style),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color: switch (style) {
                                              MemoryBookTemplate.warm =>
                                                const Color(0xffffefda),
                                              MemoryBookTemplate.botanical =>
                                                const Color(0xffe7eee1),
                                              MemoryBookTemplate.editorial =>
                                                const Color(0xffe4ebf3)
                                            },
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: bookTemplate == style
                                                    ? const Color(0xff76503a)
                                                    : Colors.transparent,
                                                width: 2)),
                                        child: Column(children: [
                                          Icon(
                                              style == MemoryBookTemplate.warm
                                                  ? Icons.photo_album_outlined
                                                  : style ==
                                                          MemoryBookTemplate
                                                              .botanical
                                                      ? Icons.grid_view_rounded
                                                      : Icons
                                                          .chrome_reader_mode_outlined,
                                              size: 34),
                                          const SizedBox(
                                              height: AppSpacing.inline),
                                          Text(
                                              switch (style) {
                                                MemoryBookTemplate.warm =>
                                                  t('暖日相册', 'Warm album'),
                                                MemoryBookTemplate.botanical =>
                                                  t('森系手记', 'Botanical'),
                                                MemoryBookTemplate.editorial =>
                                                  t('简约杂志', 'Editorial')
                                              },
                                              textAlign: TextAlign.center),
                                          if (bookTemplate == style)
                                            const Icon(Icons.check_circle,
                                                size: 16),
                                        ]))))
                        ]),
                    const SizedBox(height: AppSpacing.inline),
                    Text(t('相框式大图 · 双栏照片 · 杂志大图。生成后可预览，再保存。',
                        'Framed photos · Two-column photos · Large editorial photos. Preview the PDF before saving.')),
                    if (pets.isEmpty)
                      Text(t('先添加一位小伙伴，再开始收藏回忆。',
                          'Add a pet to start collecting memories.')),
                    const SizedBox(height: AppSpacing.item),
                    if (exporting) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: AppSpacing.inline),
                      Text(progress),
                      TextButton(
                          onPressed: () => setState(() {
                                operation++;
                                exporting = false;
                              }),
                          child: Text(t('取消导出', 'Cancel export')))
                    ] else
                      FilledButton.icon(
                          key: const ValueKey('export-memory-book'),
                          onPressed:
                              selected == null || status!['canExport'] != true
                                  ? null
                                  : exportBook,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(t('导出回忆录', 'Export memory book'))),
                    if (selected != null)
                      TextButton(
                          onPressed: exporting
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => PetDetailPage(
                                          home: widget.home,
                                          petId: selected['id'] as String))),
                          child: Text(
                              t('查看档案与管理照片', 'View profile & manage photos'))),
                  ]),
                  const SizedBox(height: AppSpacing.content),
                  panel(const Color(0xffeef0e5), [
                    Text(t('这一年，一起长大', 'A year of growing together'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.inline),
                    Text(t('看看每月的小日常、家人的照护和小伙伴的成长档案。',
                        'Explore monthly moments, family care and each pet’s milestones.')),
                    const SizedBox(height: AppSpacing.content),
                    OutlinedButton.icon(
                        key: const ValueKey('open-annual-report'),
                        onPressed: status!['canReport'] != true || exporting
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AnnualReportPage(home: widget.home))),
                        icon: const Icon(Icons.auto_graph_rounded),
                        label: Text(t('查看年度成长报告', 'View annual report'))),
                    const SizedBox(height: AppSpacing.item),
                    Text(t('新增高级权益：长期体重趋势、健康附件扩容、批量归档、历史周报与多宠趋势、临时照护和自定义权限。',
                        'Advanced benefits also include weight history, larger health attachments, batch folders, historical reports, multi-pet trends and temporary access.')),
                    TextButton(
                        onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    FamilyWeeklyPage(home: widget.home))),
                        child:
                            Text(t('家庭周报与多宠统计', 'Weekly report & pet trends'))),
                    TextButton(
                        onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    HouseholdMembersPage(home: widget.home))),
                        child: Text(t('家人与照护权限', 'People and permissions'))),
                  ]),
                ],
              ]))),
    );
  }
}

class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key, required this.home});
  final CareHomeState home;
  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  int year = DateTime.now().year;
  Map<String, dynamic>? report;
  bool loading = true, exporting = false;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
      report = null;
    });
    try {
      final zone = await widget.home.reminders.deviceZone();
      final result = await widget.home.widget.api.request('GET',
          '/benefits/annual?year=$year&zoneId=${Uri.encodeQueryComponent(zone)}');
      if (mounted) {
        setState(() => report = Map<String, dynamic>.from(result as Map));
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> export() async {
    if (report == null || exporting) return;
    setState(() {
      exporting = true;
      error = null;
    });
    try {
      final bytes = await BenefitsPdf.annual(report!);
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => BenefitPdfPreview(
                bytes: bytes,
                filename: 'petcare-annual-$year.pdf',
                title: t('$year 年度成长报告', '$year annual report'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error =
            t('PDF 生成失败，请重试。', 'Could not create the PDF. Please retry.'));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ageAt = year == now.year ? now : DateTime(year, 12, 31);
    return Scaffold(
        appBar: AppBar(title: Text(t('年度成长报告', 'Annual report'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: AppSpacing.pageInsets, children: [
                  DropdownButtonFormField<int>(
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      elevation: 3,
                      icon: const Icon(Icons.expand_more_rounded, size: 20),
                      initialValue: year,
                      decoration: InputDecoration(labelText: t('年份', 'Year')),
                      items: List.generate(
                          now.year - 1899,
                          (i) => DropdownMenuItem(
                              value: now.year - i,
                              child: Text('${now.year - i}'))),
                      onChanged: loading || exporting
                          ? null
                          : (v) {
                              year = v!;
                              load();
                            }),
                  const SizedBox(height: AppSpacing.section),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null) ...[
                    Text(error!),
                    TextButton(onPressed: load, child: Text(t('重试', 'Retry')))
                  ],
                  if (report != null) ...[
                    Text(t('这一年，我们一起长大', 'A year of growing together'),
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.item),
                    Text(
                        t('${report!['careCount']} 次照护 · ${report!['memoryCount']} 篇回忆',
                            '${report!['careCount']} care tasks · ${report!['memoryCount']} memories'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.inline),
                    Text(t(
                        '${report!['activeDays']} 个照护日，${report!['caregiverCount']} 位家人留下照护记录。',
                        '${report!['activeDays']} care days, ${report!['caregiverCount']} caregivers.')),
                    if (report!['careCount'] == 0 &&
                        report!['memoryCount'] == 0)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(t('这一年还没有记录。从一次照护或一篇回忆开始吧。',
                              'No records for this year yet. Start with a care task or memory.'))),
                    const SizedBox(height: AppSpacing.section),
                    Text(t('每月照护 / 回忆', 'Monthly care / memories'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.item),
                    for (var i = 0; i < 12; i++)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            SizedBox(
                                width: 50,
                                child: Text(t('${i + 1} 月', '${i + 1}'))),
                            Expanded(
                                child: LinearProgressIndicator(
                                    value: (report!['careCount'] as int) == 0
                                        ? 0
                                        : (report!['monthlyCare'][i] as int) /
                                            (report!['careCount'] as int),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(8),
                                    backgroundColor: const Color(0xfff1e8df))),
                            SizedBox(
                                width: 80,
                                child: Text(
                                    '${report!['monthlyCare'][i]} / ${report!['monthlyMemories'][i]}',
                                    textAlign: TextAlign.right)),
                          ])),
                    const SizedBox(height: AppSpacing.section),
                    for (final pet in report!['pets'] as List)
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.pets_outlined),
                              title: Text(pet['name'] as String),
                              subtitle: Text(
                                  '${petAgeLabel(pet['birthDate'], ageAt, chinese: widget.home.zh)}\n${t('${pet['careCount']} 次照护 · ${pet['memoryCount']} 篇回忆', '${pet['careCount']} care tasks · ${pet['memoryCount']} memories')}'))),
                    const SizedBox(height: AppSpacing.item),
                    Text(t(
                        '按家庭当前保留记录汇总，照护以年末状态去重；本年度截至当前。统计时区：${report!['zoneId']}。',
                        'Based on retained records and year-end care state; the current year is year-to-date. Time zone: ${report!['zoneId']}.')),
                    const SizedBox(height: AppSpacing.content),
                    FilledButton.icon(
                        onPressed: exporting ? null : export,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(exporting
                            ? t('正在生成…', 'Creating…')
                            : t('导出年度报告 PDF', 'Export annual PDF'))),
                  ],
                ]))));
  }
}

class BenefitPdfPreview extends StatefulWidget {
  const BenefitPdfPreview(
      {super.key,
      required this.bytes,
      required this.filename,
      required this.title});
  final Uint8List bytes;
  final String filename, title;
  @override
  State<BenefitPdfPreview> createState() => _BenefitPdfPreviewState();
}

class _BenefitPdfPreviewState extends State<BenefitPdfPreview> {
  bool saving = false;
  bool get desktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get zh => Localizations.localeOf(context).languageCode == 'zh';
  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (desktop) {
        final location = await getSaveLocation(
            suggestedName: widget.filename,
            acceptedTypeGroups: [
              const XTypeGroup(
                  label: 'PDF',
                  extensions: ['pdf'],
                  uniformTypeIdentifiers: ['com.adobe.pdf'])
            ]);
        if (location == null) return;
        await XFile.fromData(widget.bytes,
                mimeType: 'application/pdf', name: widget.filename)
            .saveTo(location.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(zh ? 'PDF 已保存' : 'PDF saved')));
        }
      } else {
        await Printing.sharePdf(bytes: widget.bytes, filename: widget.filename);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(zh ? '保存未完成，请重试。' : 'Could not save. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
            tooltip: zh ? '保存 PDF' : 'Save PDF',
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt_rounded)),
      ]),
      body: PdfPreview(
          build: (_) async => widget.bytes,
          pdfFileName: widget.filename,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false));
}
