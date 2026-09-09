import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../pets/pet_module.dart';

extension CareActions on CareHomeState {
  Future<void> addTask() async {
    if (pets.isEmpty) {
      await addPet();
      return;
    }
    final title = TextEditingController();
    String petId = pets.first['id'] as String;
    String frequency = 'NONE';
    DateTime due = DateTime.now().add(const Duration(hours: 1));
    final valid = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(t('安排照护', 'Plan care')),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButton<String>(
                        isExpanded: true,
                        value: petId,
                        items: pets
                            .map((p) => DropdownMenuItem(
                                value: p['id'] as String,
                                child: Text(p['name'] as String)))
                            .toList(),
                        onChanged: (v) => update(() => petId = v!)),
                    TextField(
                        controller: title,
                        maxLength: 120,
                        decoration: InputDecoration(
                            labelText: t('例如：晚饭后遛狗', 'e.g. Evening walk')),
                        onChanged: (_) => update(() {})),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: frequency,
                      decoration: InputDecoration(labelText: t('重复', 'Repeat')),
                      items: [
                        DropdownMenuItem(
                            value: 'NONE', child: Text(t('仅一次', 'Once'))),
                        DropdownMenuItem(
                            value: 'DAILY', child: Text(t('每天', 'Daily'))),
                        DropdownMenuItem(
                            value: 'WEEKLY', child: Text(t('每周', 'Weekly')))
                      ],
                      onChanged: (v) => update(() => frequency = v!),
                    ),
                    if (frequency != 'NONE')
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(t('首次日期须在未来 29 天内，按当前设备时区重复。',
                              'Start within 29 days. Repeats in this device’s current time zone.'))),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(dateLabel(due)),
                        onPressed: () async {
                          final date = await showDatePicker(
                              context: context,
                              initialDate: due,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2037, 12, 31));
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(due));
                          if (time != null && context.mounted) {
                            update(() => due = DateTime(date.year, date.month,
                                date.day, time.hour, time.minute));
                          }
                        }),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('取消', 'Cancel'))),
                    FilledButton(
                        onPressed: title.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                        child: Text(t('保存', 'Save')))
                  ],
                )));
    final value = title.text.trim();
    if (valid == true) {
      await perform(() async {
        await widget.api.request('POST', '/tasks', {
          'petId': petId,
          'title': value,
          'dueAt': due.toUtc().toIso8601String(),
          'frequency': frequency,
          if (frequency != 'NONE') 'zoneId': await reminders.deviceZone()
        });
      });
    }
  }

  Future<void> changeCompletion(
      Map<String, dynamic> task, bool complete) async {
    if (!complete &&
        !await confirm(
            t('撤销这次完成？', 'Undo completion?'),
            t('将重新标为待照护，并保留撤销记录。',
                'This becomes pending again. An undo event stays in history.'))) {
      return;
    }
    await perform(() async {
      await widget.api
          .request('PATCH', "/tasks/${task['id']}", {'completed': complete});
    });
  }
}
