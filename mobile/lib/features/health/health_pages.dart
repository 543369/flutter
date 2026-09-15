import 'health_timeline_page.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import '../pets/pet_module.dart';
import '../pets/memory_pages.dart';

const healthKinds = <String, (String, String, IconData)>{
  'VACCINE': ('疫苗', 'Vaccines', Icons.vaccines_outlined),
  'DEWORMING': ('驱虫', 'Deworming', Icons.bug_report_outlined),
  'MEDICATION': ('用药', 'Medication', Icons.medication_outlined),
  'ALLERGY': ('过敏', 'Allergies', Icons.warning_amber_rounded),
  'WEIGHT': ('体重', 'Weight', Icons.monitor_weight_outlined),
  'VISIT': ('就诊', 'Vet visits', Icons.local_hospital_outlined),
};
String healthDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class HealthRecordsPage extends StatefulWidget {
  const HealthRecordsPage({super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  @override
  State<HealthRecordsPage> createState() => _HealthRecordsPageState();
}

class _HealthRecordsPageState extends State<HealthRecordsPage> {
  final items = <Map<String, dynamic>>[];
  final selected = <String>{};
  String kind = '', error = '';
  bool loading = false, more = false, advanced = false;
  int limit = 2;
  String t(String z, String e) => widget.home.t(z, e);
  String get path => '/pets/${widget.petId}/health';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool reset = true}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
      if (reset) {
        items.clear();
        selected.clear();
      }
    });
    try {
      final result = await widget.home.widget.api
          .request('GET', '$path?offset=${items.length}&kind=$kind');
      if (mounted) {
        setState(() {
          items.addAll((result['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map)));
          more = result['hasMore'] as bool;
          advanced = result['advanced'] as bool;
          limit = result['attachmentLimit'] as int;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => HealthRecordEditor(
            home: widget.home,
            petId: widget.petId,
            record: item,
            limit: limit));
    if (saved == true && mounted) await load();
  }

  Future<void> details(Map<String, dynamic> item) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HealthRecordDetail(
            home: widget.home,
            petId: widget.petId,
            id: item['id'] as String,
            limit: limit)));
    if (mounted) await load();
  }

  Future<void> organize() async {
    final controller = TextEditingController();
    final folder = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(t('批量归档', 'Organize records')),
                content: TextField(
                    controller: controller,
                    maxLength: 60,
                    decoration: InputDecoration(
                        labelText:
                            t('文件夹名称（留空移出文件夹）', 'Folder (empty to clear)'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(t('取消', 'Cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, controller.text.trim()),
                      child: Text(t('归档', 'Organize')))
                ]));
    if (folder == null || !mounted) return;
    setState(() => loading = true);
    try {
      await widget.home.widget.api.request('POST', '$path/organize',
          {'ids': selected.toList(), 'folder': folder});
      if (mounted) {
        setState(() => loading = false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('健康档案', 'Health records')), actions: [
        IconButton(
            tooltip: t('时间线与导出', 'Timeline & export'),
            onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => HealthTimelinePage(
                        home: widget.home, petId: widget.petId))),
            icon: const Icon(Icons.ios_share_outlined))
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: loading ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: Text(t('新增记录', 'Add record'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                  children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: const Color(0xffe6eee2),
                            borderRadius: BorderRadius.circular(28)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.favorite_outline,
                                  size: 32, color: Color(0xff657e5f)),
                              const SizedBox(height: 12),
                              Text(
                                  t('把每一次照顾，\n好好记下来。',
                                      'Every detail of care,\nin one place.'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                              const SizedBox(height: 10),
                              Text(t('基础记录免费 · 疫苗、驱虫、用药、过敏、体重与就诊',
                                  'Free basic records · Vaccines, medication, weight and more')),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: advanced
                                      ? () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => HealthTrendPage(
                                                  home: widget.home,
                                                  petId: widget.petId)))
                                      : null,
                                  icon: const Icon(Icons.show_chart),
                                  label: Text(t('长期体重趋势 · 高级权益',
                                      'Long-term weight trends · Advanced'))),
                            ])),
                    const SizedBox(height: 20),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                          label: Text(t('全部', 'All')),
                          selected: kind.isEmpty,
                          onSelected: loading
                              ? null
                              : (_) {
                                  setState(() => kind = '');
                                  load();
                                }),
                      for (final entry in healthKinds.entries)
                        ChoiceChip(
                            avatar: Icon(entry.value.$3, size: 18),
                            label: Text(t(entry.value.$1, entry.value.$2)),
                            selected: kind == entry.key,
                            onSelected: loading
                                ? null
                                : (_) {
                                    setState(() => kind = entry.key);
                                    load();
                                  }),
                    ]),
                    const SizedBox(height: 12),
                    if (advanced)
                      Row(children: [
                        Expanded(
                            child: Text(
                                t('勾选记录可批量归档', 'Select records to organize'))),
                        const Spacer(),
                        TextButton(
                            onPressed:
                                selected.isEmpty || loading ? null : organize,
                            child: Text(t('归档 ${selected.length} 项',
                                'Organize ${selected.length}')))
                      ]),
                    if (error.isNotEmpty)
                      Column(children: [
                        Text(error),
                        TextButton(
                            onPressed: loading
                                ? null
                                : () => load(reset: items.isEmpty),
                            child: Text(t('重试', 'Retry')))
                      ]),
                    if (loading) const LinearProgressIndicator(),
                    if (items.isEmpty && !loading && error.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(t('还没有健康记录，记下第一次照顾吧。',
                              'No health records yet. Add the first one.'))),
                    for (final item in items)
                      Card(
                          color: const Color(0xfffaf2e8),
                          child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: advanced
                                  ? Checkbox(
                                      value: selected.contains(item['id']),
                                      onChanged: loading
                                          ? null
                                          : (value) => setState(() {
                                                if (value == true &&
                                                    selected.length < 100) {
                                                  selected.add(
                                                      item['id'] as String);
                                                } else {
                                                  selected.remove(item['id']);
                                                }
                                              }))
                                  : Icon(healthKinds[item['kind']]!.$3),
                              title: Text(item['title'] as String),
                              subtitle: Text(
                                  '${item['happenedOn']} · ${t(healthKinds[item['kind']]!.$1, healthKinds[item['kind']]!.$2)}${item['weightKg'] == null ? '' : ' · ${item['weightKg']} kg'}${item['folder'] == '' ? '' : '\n${item['folder']}'}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: loading ? null : () => details(item))),
                    if (more)
                      TextButton(
                          onPressed: loading ? null : () => load(reset: false),
                          child: Text(t('加载更多', 'Load more'))),
                  ]))));
}

class HealthRecordEditor extends StatefulWidget {
  const HealthRecordEditor(
      {super.key,
      required this.home,
      required this.petId,
      required this.limit,
      this.record});
  final CareHomeState home;
  final String petId;
  final int limit;
  final Map<String, dynamic>? record;
  @override
  State<HealthRecordEditor> createState() => _HealthRecordEditorState();
}

class _HealthRecordEditorState extends State<HealthRecordEditor> {
  late final title =
      TextEditingController(text: widget.record?['title'] as String? ?? '');
  late final notes =
      TextEditingController(text: widget.record?['notes'] as String? ?? '');
  late final weight =
      TextEditingController(text: widget.record?['weightKg']?.toString() ?? '');
  late String kind = widget.record?['kind'] as String? ?? 'VACCINE';
  late DateTime date =
      DateTime.tryParse(widget.record?['happenedOn'] as String? ?? '') ??
          DateTime.now();
  late final photos =
      List<String>.from(widget.record?['photos'] as List? ?? []);
  bool saving = false, picking = false;
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    weight.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    setState(() => picking = true);
    try {
      final photo = await widget.home.pickPetPhoto();
      if (mounted && photo != null) setState(() => photos.add(photo));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (saving || picking) return;
    final kg = double.tryParse(weight.text.trim());
    if (kind == 'WEIGHT' &&
        (kg == null || !kg.isFinite || kg <= 0 || kg > 9999)) {
      setState(() => error = t('请输入有效体重（kg）', 'Enter a valid weight in kg'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.home.widget.api.request(
          widget.record == null ? 'POST' : 'PATCH',
          '/pets/${widget.petId}/health${widget.record == null ? '' : '/${widget.record!['id']}'}',
          {
            'kind': kind,
            'title': title.text.trim(),
            'notes': notes.text.trim(),
            'happenedOn': healthDay(date),
            'weightKg': kind == 'WEIGHT' ? kg : null,
            'photos': photos
          });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ProfileDialog(
          title: t('记录健康小事', 'Health record'),
          subtitle: t('如实记录观察和医嘱，方便下一次查阅。',
              'Keep observations and veterinary instructions together.'),
          saveLabel: t('保存记录', 'Save record'),
          cancelLabel: t('取消', 'Cancel'),
          saving: saving || picking,
          error: error,
          onSave: title.text.trim().isEmpty ? null : save,
          children: [
            DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: kind,
                decoration: InputDecoration(labelText: t('记录类型', 'Type')),
                items: healthKinds.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(t(e.value.$1, e.value.$2))))
                    .toList(),
                onChanged: saving ? null : (v) => setState(() => kind = v!)),
            const SizedBox(height: 12),
            TextField(
                controller: title,
                enabled: !saving,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: t('名称 / 主题', 'Title'),
                    hintText: t('例如：年度疫苗、复诊检查', 'e.g. Annual vaccination'))),
            OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now());
                        if (d != null && mounted) setState(() => date = d);
                      },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(healthDay(date))),
            if (kind == 'WEIGHT')
              TextField(
                  controller: weight,
                  enabled: !saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t('体重（kg）', 'Weight (kg)'))),
            const SizedBox(height: 12),
            TextField(
                controller: notes,
                enabled: !saving,
                maxLength: 5000,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                    labelText: t('详细说明', 'Notes'),
                    hintText: t('药品、剂量、疗程、过敏表现或医院与医嘱',
                        'Medication, dosage, allergy details or veterinary notes'))),
            Text(t('图片附件 ${photos.length}/${widget.limit}',
                'Image attachments ${photos.length}/${widget.limit}')),
            Text(t('健康附件计入家庭共享空间，与档案照片和回忆录照片共用额度。',
                'Health attachments count toward the same household storage as pet profile and memory photos.')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in photos.indexed)
                SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(children: [
                      Positioned.fill(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: MemoryPhoto(data: entry.$2))),
                      Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                              onPressed: saving
                                  ? null
                                  : () =>
                                      setState(() => photos.removeAt(entry.$1)),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.white),
                              icon: const Icon(Icons.close, size: 16)))
                    ]))
            ]),
            OutlinedButton.icon(
                onPressed: saving || picking || photos.length >= widget.limit
                    ? null
                    : pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(t('添加附件照片', 'Add photo attachment'))),
          ]);
}

class HealthRecordDetail extends StatefulWidget {
  const HealthRecordDetail(
      {super.key,
      required this.home,
      required this.petId,
      required this.id,
      required this.limit});
  final CareHomeState home;
  final String petId, id;
  final int limit;
  @override
  State<HealthRecordDetail> createState() => _HealthRecordDetailState();
}

class _HealthRecordDetailState extends State<HealthRecordDetail> {
  Map<String, dynamic>? record;
  String? error;
  bool busy = false;
  String t(String z, String e) => widget.home.t(z, e);
  String get path => '/pets/${widget.petId}/health/${widget.id}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.home.widget.api.request('GET', path);
      if (mounted) setState(() => record = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    if (!await widget.home.confirm(t('删除健康记录？', 'Delete health record?'),
            t('记录和附件将一同删除。', 'This also deletes its attachments.')) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.home.widget.api.request('DELETE', path);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('健康记录详情', 'Health record details'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null) ...[
                  Text(error!),
                  TextButton(
                      onPressed: busy ? null : load,
                      child: Text(t('重试', 'Retry')))
                ],
                if (record != null) ...[
                  Icon(healthKinds[record!['kind']]!.$3,
                      size: 48, color: const Color(0xff7a8f69)),
                  const SizedBox(height: 16),
                  Text(record!['title'] as String,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                      '${record!['happenedOn']} · ${t(healthKinds[record!['kind']]!.$1, healthKinds[record!['kind']]!.$2)}'),
                  if (record!['weightKg'] != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('${record!['weightKg']} kg',
                            style: Theme.of(context).textTheme.headlineLarge)),
                  const SizedBox(height: 18),
                  SelectableText(record!['notes'] as String),
                  const SizedBox(height: 20),
                  for (final p in record!['photos'] as List)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AspectRatio(
                            aspectRatio: 1.25,
                            child: MemoryPhoto(
                                data: p as String, fit: BoxFit.contain))),
                  Text(t('创建时间：${record!['createdAt']}',
                      'Created: ${record!['createdAt']}')),
                  Text(t('文件夹：${record!['folder']}',
                      'Folder: ${record!['folder']}')),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final changed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => HealthRecordEditor(
                                      home: widget.home,
                                      petId: widget.petId,
                                      limit: widget.limit,
                                      record: record));
                              if (changed == true && mounted) await load();
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(t('编辑记录', 'Edit record'))),
                  TextButton(
                      onPressed: busy ? null : remove,
                      child: Text(t('删除记录', 'Delete record'))),
                ]
              ]))));
}

class HealthTrendPage extends StatefulWidget {
  const HealthTrendPage({super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  @override
  State<HealthTrendPage> createState() => _HealthTrendPageState();
}

class _HealthTrendPageState extends State<HealthTrendPage> {
  List<dynamic>? items;
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final r = await widget.home.widget.api
          .request('GET', '/pets/${widget.petId}/health/trend');
      if (mounted) setState(() => items = r['items'] as List);
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('长期体重趋势', 'Weight history'))),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text(t('每一次变化，都有迹可循。', 'A record of every little change.'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(t('按月展示平均体重与范围，缺少记录的月份不推算。',
            'Monthly mean and range. Missing months are not estimated.')),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: load, child: Text(t('重试', 'Retry')))
        ] else if (items == null)
          const LinearProgressIndicator(),
        if (items != null && items!.isEmpty)
          Padding(
              padding: const EdgeInsets.all(32),
              child: Text(t(
                  '添加体重记录后，这里会显示长期变化。', 'Add weight records to see trends.'))),
        if (items != null)
          for (final row in items!)
            Card(
                color: const Color(0xffeaf0e4),
                child: ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text(
                        '${row['month']} · ${(row['weightKg'] as num).toStringAsFixed(2)} kg'),
                    subtitle: Text(
                        '${row['minKg']}–${row['maxKg']} kg · ${row['count']} ${t('次记录', 'records')}'))),
      ]));
}
