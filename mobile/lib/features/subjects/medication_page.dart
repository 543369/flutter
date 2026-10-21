import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/theme/app_spacing.dart';

class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key, required this.home, required this.task});
  final CareHomeState home;
  final Map<String, dynamic> task;
  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  late final drug =
      TextEditingController(text: widget.task['title'] as String?);
  final dose = TextEditingController(), notes = TextEditingController();
  final logs = <Map<String, dynamic>>[];
  String outcome = 'TAKEN';
  DateTime actual = DateTime.now();
  bool busy = false, saved = false;
  String? error;
  Map<String, dynamic>? submitted;
  late final String requestId = List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join()
      .replaceAllMapped(RegExp(r'^(.{8})(.{4})(.{4})(.{4})(.{12})$'),
          (m) => '${m[1]}-${m[2]}-${m[3]}-${m[4]}-${m[5]}');
  String t(String z, String e) => widget.home.t(z, e);
  String get path => '/tasks/${widget.task['id']}/medication';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    drug.dispose();
    dose.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final r = await widget.home.widget.api.request('GET', path) as Map;
      if (mounted) {
        setState(() {
          logs
            ..clear()
            ..addAll((r['items'] as List)
                .map((v) => Map<String, dynamic>.from(v as Map)));
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> time() async {
    final d = await showDatePicker(
        context: context,
        initialDate: actual,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (d == null || !mounted) return;
    final v = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(actual));
    if (v != null && mounted) {
      setState(
          () => actual = DateTime(d.year, d.month, d.day, v.hour, v.minute));
    }
  }

  String outcomeText(String value) => switch (value) {
        'TAKEN' => t('已服用', 'Taken'),
        'NOT_TAKEN' => t('未服用', 'Not taken'),
        'REFUSED' => t('拒绝服用', 'Refused'),
        _ => t('暂停用药', 'Held')
      };
  Future<void> save() async {
    if (busy) return;
    if (drug.text.trim().isEmpty || dose.text.trim().isEmpty) {
      setState(() =>
          error = t('请填写药名和医嘱剂量。', 'Enter the medicine and prescribed dose.'));
      return;
    }
    if (actual.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      setState(() =>
          error = t('实际时间不能晚于现在。', 'The actual time cannot be in the future.'));
      return;
    }
    if (widget.home.widget.api.offlineCare.pendingCount > 0) {
      setState(() => error = t('请先处理待同步操作后记录用药。',
          'Resolve pending changes before recording medication.'));
      return;
    }
    submitted ??= {
      'requestId': requestId,
      'revision': widget.task['revision'] ?? 0,
      'outcome': outcome,
      'actualAt': actual.toUtc().toIso8601String(),
      'medication': drug.text.trim(),
      'dose': dose.text.trim(),
      'notes': notes.text.trim()
    };
    setState(() => busy = true);
    try {
      await widget.home.widget.api.request('POST', path, submitted);
      if (!mounted) return;
      setState(() => saved = true);
      await load();
      await widget.home.refreshQuietly();
    } catch (e) {
      if (mounted) {
        setState(() => error = t('未确认保存成功。可使用相同内容重试，系统会避免重复记录；也可重新加载核对。',
            'Save was not confirmed. Retry the same submission safely, or reload to check saved records.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = saved ||
        logs.isNotEmpty ||
        widget.task['completed'] == true ||
        widget.task['skipped'] == true ||
        widget.task['cancelled'] == true;
    final locked = busy || submitted != null;
    return Scaffold(
        appBar: AppBar(title: Text(t('用药记录', 'Medication record'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: AppSpacing.pageInsets, children: [
                  Text(t('按已有医嘱记录药名、剂量及实际服用／观察时间，不自动建议剂量。此记录需要联网；未服用不会计为已完成。',
                      'Record the prescribed medicine, dose and actual or observed time. No dose is suggested. An internet connection is required; not taken does not count as completed.')),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null) Text(error!),
                  TextButton(
                      onPressed: busy ? null : load,
                      child: Text(t('重新加载', 'Reload'))),
                  if (!closed &&
                      widget.home.can('CARE') &&
                      widget.home.can('HEALTH') &&
                      widget.home.pets
                              .where((p) => p['id'] == widget.task['petId'])
                              .firstOrNull?['canCareSubject'] !=
                          false) ...[
                    TextField(
                        controller: drug,
                        enabled: !locked,
                        maxLength: 120,
                        decoration:
                            InputDecoration(labelText: t('药品名称', 'Medicine'))),
                    TextField(
                        controller: dose,
                        enabled: !locked,
                        maxLength: 120,
                        decoration: InputDecoration(
                            labelText:
                                t('医嘱剂量与单位', 'Prescribed dose and unit'))),
                    DropdownButton<String>(
                        value: outcome,
                        isExpanded: true,
                        items: [
                          for (final v in [
                            'TAKEN',
                            'NOT_TAKEN',
                            'REFUSED',
                            'HELD'
                          ])
                            DropdownMenuItem(
                                value: v, child: Text(outcomeText(v)))
                        ],
                        onChanged: locked
                            ? null
                            : (v) => setState(() => outcome = v!)),
                    ListTile(
                        title: Text(t('实际服用／观察时间', 'Actual or observed time')),
                        subtitle: Text(widget.home.dateLabel(actual)),
                        onTap: locked ? null : time,
                        trailing: const Icon(Icons.edit_calendar)),
                    TextField(
                        controller: notes,
                        enabled: !locked,
                        maxLength: 1000,
                        maxLines: 3,
                        decoration:
                            InputDecoration(labelText: t('备注', 'Notes'))),
                    FilledButton(
                        onPressed: busy ? null : save,
                        child: Text(submitted == null
                            ? t('保存用药结果', 'Save medication outcome')
                            : t('重试同一笔记录', 'Retry this submission'))),
                  ],
                  for (final log in logs)
                    Card(
                        child: Padding(
                            padding: AppSpacing.cardInsets,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${log['medication']} · ${log['dose']}'),
                                  Text(outcomeText(log['outcome'] as String)),
                                  Text(widget.home.dateLabel(
                                      DateTime.parse(log['actualAt'] as String)
                                          .toLocal())),
                                  Text(log['notes'] as String)
                                ]))),
                ]))));
  }
}
