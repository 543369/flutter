import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import 'care_actions.dart';

extension CareView on CareHomeState {
  List<Map<String, dynamic>> get history => (data?['history'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();

  List<Map<String, dynamic>> get plans => (data?['plans'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();

  List<Widget> careView() {
    final remaining = tasks.where((v) => v['completed'] != true).length;
    final visible = tasks
        .where((v) => careFilter == 'completed'
            ? v['completed'] == true
            : v['completed'] != true)
        .toList();
    return [
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0xffdceadf),
              borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('照护看板', 'CARE BOARD'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(t('$remaining 项待照护', '$remaining tasks to do'),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(t('一起完成每一个小日常。', 'Every little routine, together.')),
          ])),
      if (error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(t('同步失败，当前显示上次的数据。请下拉重试。',
                'Sync failed. Showing the last update. Pull to retry.'))),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('到时提醒', 'Care reminders')),
          subtitle: Text(reminderError != null
              ? t('提醒设置失败，请重新开启或检查系统权限。',
                  'Reminder setup failed. Retry or check system permissions.')
              : t('仅提醒本机已同步的事项',
                  'Reminds you about tasks synced to this device')),
          value: reminders.enabled,
          onChanged: busy ? null : toggleReminders),
      Wrap(spacing: 8, children: [
        for (final item in [
          ('pending', t('待照护', 'Pending')),
          ('completed', t('已完成', 'Completed')),
          ('history', t('记录', 'History')),
          ('plans', t('重复计划', 'Plans'))
        ])
          ChoiceChip(
              label: Text(item.$2),
              selected: careFilter == item.$1,
              onSelected: (_) => updateUi(() => careFilter = item.$1)),
      ]),
      const SizedBox(height: 12),
      if (careFilter == 'history') ...[
        Text(t('最近 100 条操作记录', 'Latest 100 care events'),
            style: Theme.of(context).textTheme.bodySmall),
        if (history.isEmpty)
          empty(
              t('还没有照护记录', 'No care history yet'),
              t('家人完成事项后，会在这里留下记录。',
                  'Completed care will appear here with the caregiver.'),
              Icons.history),
        ...history.map((event) => Card(
                child: ListTile(
              leading: Icon(event['action'] == 'COMPLETED'
                  ? Icons.check_circle_outline
                  : Icons.undo),
              title: Text("${event['petName']} · ${event['title']}"),
              subtitle: Text(
                  "${event['actor'] ?? t('已退出的家人', 'Former member')} · ${event['action'] == 'COMPLETED' ? t('完成', 'Completed') : t('撤销完成', 'Reopened')}\n${dateLabel(DateTime.parse(event['at'] as String).toLocal())}"),
            ))),
      ] else if (careFilter == 'plans') ...[
        if (plans.isEmpty)
          empty(
              t('还没有重复计划', 'No recurring plans'),
              t('安排照护时选择每天或每周。', 'Choose daily or weekly when planning care.'),
              Icons.repeat),
        ...plans.map((plan) => Card(
                child: ListTile(
              title: Text("${plan['petName']} · ${plan['title']}"),
              subtitle: Text(
                  "${plan['frequency'] == 'DAILY' ? t('每天', 'Daily') : t('每周', 'Weekly')} · ${plan['zoneId']}\n${plan['active'] == true ? t('进行中', 'Active') : t('已停止', 'Stopped')}"),
              trailing: plan['active'] != true
                  ? null
                  : IconButton(
                      tooltip: t('停止重复', 'Stop repeating'),
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: busy
                          ? null
                          : () async {
                              if (await confirm(
                                  t('停止这个重复计划？', 'Stop this plan?'),
                                  t('取消未来未完成事项，保留已完成、逾期事项和历史记录。',
                                      'Cancel future pending care. Completed, overdue care and history remain.'))) {
                                await perform(() async {
                                  await widget.api.request(
                                      'DELETE', "/plans/${plan['id']}");
                                });
                              }
                            }),
            ))),
      ] else ...[
        if (visible.isEmpty)
          empty(
              t('这里暂时没有事项', 'No tasks here'),
              t('安排照护，或切换查看完成记录。', 'Plan care or view your care history.'),
              Icons.favorite_outline),
        ...visible.map((task) => Card(
                child: CheckboxListTile(
              value: task['completed'] as bool,
              onChanged:
                  busy ? null : (value) => changeCompletion(task, value!),
              title: Text(task['title'] as String),
              subtitle: Text(
                  "${task['petName']} · ${dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())}${task['planId'] != null ? ' · ↻' : ''}${task['completed'] != true && DateTime.parse(task['dueAt'] as String).isBefore(DateTime.now()) ? t(' · 已逾期', ' · Overdue') : ''}"),
            ))),
      ],
      const SizedBox(height: 16),
      Text(
          t('本机最多保留最近的 60 条未来提醒，打开 App 会补充。家人在其他设备完成后，本机须同步才能取消提醒；Android 提醒可能受省电策略延迟。',
              'Up to 60 upcoming reminders are saved on this device and refreshed when you open the app. Care completed elsewhere cancels reminders after sync. Android battery settings may delay alerts.'),
          style: Theme.of(context).textTheme.bodySmall),
    ];
  }
}
