import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import 'care_kind.dart';

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, required this.home});
  final CareHomeState home;
  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final title = TextEditingController();
  late String petId = widget.home.selectedPet!['id'] as String;
  CareKind kind = CareKind.custom;
  String frequency = 'NONE';
  DateTime due = DateTime.now().add(const Duration(hours: 1));
  bool saving = false;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || saving) return;
    if (frequency != 'NONE' &&
        (due.isBefore(DateTime.now()) ||
            due.isAfter(DateTime.now().add(const Duration(days: 29))))) {
      setState(() => error = t('重复计划的首次时间请选择未来 29 天内。',
          'Start recurring care within the next 29 days.'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.home.widget.api.request('POST', '/tasks', {
        'petId': petId,
        'title': title.text.trim(),
        'careType': kind.code,
        'dueAt': due.toUtc().toIso8601String(),
        'frequency': frequency,
        if (frequency != 'NONE')
          'zoneId': await widget.home.reminders.deviceZone(),
      });
      if (mounted) Navigator.of(context).pop(petId);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: due,
        firstDate: DateTime(2020),
        lastDate: DateTime(2037, 12, 31));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(due));
    if (time != null && mounted) {
      setState(() => due =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  @override
  Widget build(BuildContext context) => ProfileDialog(
        title: t('安排照护', 'Plan care'),
        subtitle:
            t('选一种照护，也可以写下专属安排。', 'Choose a care type or make it your own.'),
        saving: saving,
        error: error,
        onSave: title.text.trim().isEmpty ? null : save,
        saveLabel: t('保存', 'Save'),
        cancelLabel: t('取消', 'Cancel'),
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('task-pet'),
            initialValue: petId,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: t('照护谁', 'Pet'),
                prefixIcon: const Icon(Icons.pets_outlined)),
            items: widget.home.pets
                .map((p) => DropdownMenuItem(
                    value: p['id'] as String, child: Text(p['name'] as String)))
                .toList(),
            onChanged: saving ? null : (v) => setState(() => petId = v!),
          ),
          const SizedBox(height: 20),
          Text(t('照护类型', 'Care type'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          LayoutBuilder(
              builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CareKind.values
                      .map((item) => SizedBox(
                            width: (constraints.maxWidth - 16) / 3,
                            child: Semantics(
                              selected: kind == item,
                              button: true,
                              child: Material(
                                color: kind == item
                                    ? const Color(0xffffe7c4)
                                    : const Color(0xfffaf6f0),
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey('care-type-${item.code}'),
                                  onTap: saving
                                      ? null
                                      : () => setState(() {
                                            kind = item;
                                            if (item == CareKind.custom) {
                                              if (CareKind.values.any((v) =>
                                                  title.text ==
                                                  v.label(widget.home.zh))) {
                                                title.clear();
                                              }
                                            } else {
                                              title.text =
                                                  item.label(widget.home.zh);
                                            }
                                          }),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 2),
                                      child: Column(children: [
                                        item.picture(size: 54),
                                        const SizedBox(height: 4),
                                        Text(item.label(widget.home.zh),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: kind == item
                                                    ? FontWeight.w700
                                                    : FontWeight.w500)),
                                      ])),
                                ),
                              ),
                            ),
                          ))
                      .toList())),
          const SizedBox(height: 18),
          TextField(
              controller: title,
              enabled: !saving,
              maxLength: 120,
              key: const ValueKey('task-title'),
              decoration: InputDecoration(
                  labelText: t('安排名称', 'Plan name'),
                  hintText: t('例如：晚饭后遛狗', 'e.g. Evening walk')),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: frequency,
            decoration: InputDecoration(
                labelText: t('重复', 'Repeat'),
                prefixIcon: const Icon(Icons.repeat_rounded)),
            items: [
              DropdownMenuItem(value: 'NONE', child: Text(t('仅一次', 'Once'))),
              DropdownMenuItem(value: 'DAILY', child: Text(t('每天', 'Daily'))),
              DropdownMenuItem(value: 'WEEKLY', child: Text(t('每周', 'Weekly'))),
            ],
            onChanged: saving ? null : (v) => setState(() => frequency = v!),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
              onPressed: saving ? null : pickDate,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(widget.home.dateLabel(due))),
          if (frequency != 'NONE')
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t('首次时间为未来 29 天内，按当前设备时区重复。',
                    'Starts within 29 days and repeats in this device’s time zone.'))),
        ],
      );
}
