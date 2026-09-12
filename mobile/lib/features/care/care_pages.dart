import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import 'care_actions.dart';
import 'care_view.dart';
import 'care_kind.dart';

extension CarePages on CareHomeState {
  String frequencyLabel(Map<String, dynamic>? plan) =>
      switch (plan?['frequency']) {
        'DAILY' => t('每天', 'Daily'),
        'WEEKLY' => t('每周', 'Weekly'),
        _ => t('单次', 'Once'),
      };

  Map<String, dynamic>? planFor(Map<String, dynamic> task) =>
      plans.where((plan) => plan['id'] == task['planId']).firstOrNull;

  String eventAction(Map<String, dynamic> event) =>
      event['action'] == 'REOPENED'
          ? t('已撤销完成', 'Completion undone')
          : t('已完成照护', 'Care completed');

  Future<void> _openCarePage(
      String title, List<Widget> Function(VoidCallback refresh) content) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _CarePage(home: this, title: title, content: content)));
  }

  Widget _detailField(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 94, child: Text(label)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Color(0xff34231e), fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _detailCard(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      );

  Widget _sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge));

  Widget _scheduleCard(Map<String, dynamic> task) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: CareKind.of(task).picture(size: 52),
          title: Text(task['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())}\n'
              '${task['petName']} · ${frequencyLabel(planFor(task))}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openTaskDetails(task),
        ),
      );

  Future<void> openSchedules() {
    String filter = 'pending';
    return _openCarePage(t('全部安排', 'All plans'), (refresh) {
      final petId = selectedPet?['id'];
      final petTasks = tasks.where((task) => task['petId'] == petId).toList()
        ..sort((a, b) => DateTime.parse(a['dueAt'] as String)
            .compareTo(DateTime.parse(b['dueAt'] as String)));
      final petPlans = plans.where((plan) => plan['petId'] == petId).toList();
      final visible = petTasks
          .where(
              (task) => (task['completed'] == true) == (filter == 'completed'))
          .toList();
      return [
        Text(t('${selectedPet?['name'] ?? '宠物'}的照护安排',
            'Care for ${selectedPet?['name'] ?? 'your pet'}')),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('create-schedule'),
          onPressed: busy
              ? null
              : () async {
                  final existing = tasks.map((task) => task['id']).toSet();
                  await addTask();
                  final created = tasks
                      .where((task) => !existing.contains(task['id']))
                      .firstOrNull;
                  if (created != null) {
                    if (filter != 'recurring' || created['planId'] == null) {
                      filter = 'pending';
                    }
                    refresh();
                  }
                },
          icon: const Icon(Icons.add_rounded),
          label: Text(t('新建安排', 'New plan')),
        ),
        const SizedBox(height: 20),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'pending', label: Text(t('待照护', 'Pending'))),
            ButtonSegment(
                value: 'completed', label: Text(t('已完成', 'Completed'))),
            ButtonSegment(
                value: 'recurring', label: Text(t('重复计划', 'Recurring'))),
          ],
          selected: {filter},
          onSelectionChanged: (values) {
            filter = values.first;
            refresh();
          },
        ),
        const SizedBox(height: 20),
        if (filter == 'recurring') ...[
          if (petPlans.isEmpty)
            empty(
                t('还没有重复计划', 'No recurring plans'),
                t('点击新建安排，选择每天或每周。',
                    'Create a plan and choose daily or weekly.'),
                Icons.repeat_rounded),
          for (final plan in petPlans)
            Card(
              child: ListTile(
                leading: CareKind.of(plan).picture(size: 52),
                title: Text(plan['title'] as String),
                subtitle: Text(
                    '${frequencyLabel(plan)} · ${plan['active'] == true ? t('进行中', 'Active') : t('已停止', 'Stopped')}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openPlanDetails(plan),
              ),
            ),
        ] else ...[
          if (visible.isEmpty)
            empty(
                filter == 'completed'
                    ? t('还没有已完成安排', 'No completed plans')
                    : t('还没有待照护安排', 'No pending plans'),
                t('随时可以通过上方按钮新建安排。',
                    'Use the button above to plan care anytime.'),
                Icons.event_available_rounded),
          ...visible.map(_scheduleCard),
        ],
      ];
    });
  }

  Future<void> openTaskDetails(Map<String, dynamic> original) =>
      _openCarePage(t('安排详情', 'Plan details'), (_) {
        final task =
            tasks.where((item) => item['id'] == original['id']).firstOrNull;
        if (task == null) {
          return [
            empty(
                t('此安排已不可用', 'This plan is unavailable'),
                t('返回查看最新安排。', 'Go back to view current plans.'),
                Icons.event_busy_rounded)
          ];
        }
        final plan = planFor(task);
        final events =
            history.where((event) => event['taskId'] == task['id']).toList();
        final completed = task['completed'] == true;
        return [
          CareKind.of(task).picture(size: 148),
          const SizedBox(height: 16),
          _detailCard([
            Text(task['title'] as String,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            _detailField(t('宠物', 'Pet'), task['petName'] as String),
            _detailField(t('安排时间', 'Scheduled'),
                dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())),
            _detailField(t('照护类型', 'Care type'), CareKind.of(task).label(zh)),
            _detailField(t('重复', 'Repeat'), frequencyLabel(plan)),
            _detailField(t('状态', 'Status'),
                completed ? t('已完成', 'Completed') : t('待照护', 'Pending')),
          ]),
          FilledButton.icon(
            onPressed: busy ? null : () => changeCompletion(task, !completed),
            icon: Icon(
                completed ? Icons.undo_rounded : Icons.check_circle_rounded),
            label: Text(completed
                ? t('撤销完成', 'Undo completion')
                : t('标记完成', 'Mark as done')),
          ),
          if (plan != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openPlanDetails(plan),
              icon: const Icon(Icons.repeat_rounded),
              label: Text(t('查看重复计划', 'View recurring plan')),
            ),
          ],
          _sectionTitle(t('相关照护记录', 'Related care history')),
          if (events.isEmpty)
            Text(t('完成照护后，会在这里记录时间和照护人。',
                'Completion time and caregiver will appear here.')),
          ...events.map(_historyLink),
        ];
      });

  Widget _historyLink(Map<String, dynamic> event) => Card(
      color: const Color(0xffe3f0fb),
      child: ListTile(
        title: Text(eventAction(event)),
        subtitle: Text(
            '${event['actor'] ?? t('家庭成员', 'Family member')} · ${dateLabel(DateTime.parse(event['at'] as String).toLocal())}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => openRecordDetails(event),
      ));

  Future<void> openRecordDetails(Map<String, dynamic> event) =>
      _openCarePage(t('记录详情', 'Record details'), (_) {
        final task =
            tasks.where((item) => item['id'] == event['taskId']).firstOrNull;
        return [
          CareKind.of(event).picture(size: 148),
          const SizedBox(height: 16),
          _detailCard([
            Text(event['title'] as String,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            _detailField(t('宠物', 'Pet'), event['petName'] as String),
            _detailField(t('记录时间', 'Recorded'),
                dateLabel(DateTime.parse(event['at'] as String).toLocal())),
            _detailField(t('照护人', 'Caregiver'),
                event['actor'] as String? ?? t('家庭成员', 'Family member')),
            _detailField(t('操作', 'Action'), eventAction(event)),
          ]),
          if (task != null)
            OutlinedButton.icon(
              onPressed: () => openTaskDetails(task),
              icon: const Icon(Icons.event_note_rounded),
              label: Text(t('查看关联安排', 'View linked plan')),
            ),
        ];
      });

  Future<void> openPlanDetails(Map<String, dynamic> original) =>
      _openCarePage(t('重复计划详情', 'Recurring plan details'), (_) {
        final plan =
            plans.where((item) => item['id'] == original['id']).firstOrNull ??
                original;
        final occurrences = tasks
            .where((task) => task['planId'] == plan['id'])
            .toList()
          ..sort((a, b) => DateTime.parse(a['dueAt'] as String)
              .compareTo(DateTime.parse(b['dueAt'] as String)));
        return [
          _detailCard([
            Text(plan['title'] as String,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            _detailField(t('宠物', 'Pet'), plan['petName'] as String),
            _detailField(t('重复', 'Repeat'), frequencyLabel(plan)),
            if (plan['zoneId'] != null)
              _detailField(t('时区', 'Time zone'), plan['zoneId'] as String),
            _detailField(
                t('状态', 'Status'),
                plan['active'] == true
                    ? t('进行中', 'Active')
                    : t('已停止', 'Stopped')),
          ]),
          _sectionTitle(t('关联安排', 'Scheduled care')),
          if (occurrences.isEmpty)
            Text(t('暂无关联安排。', 'No scheduled care available.')),
          ...occurrences.map(_scheduleCard),
        ];
      });

  Future<void> openReminderSettings() => _openCarePage(
      t('提醒设置', 'Reminder settings'),
      (_) => [
            _detailCard([
              const Icon(Icons.notifications_none_rounded,
                  size: 44, color: Color(0xffd95e32)),
              const SizedBox(height: 16),
              Text(t('照护时间到了，提醒你', 'A reminder when care is due'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(t('为这台设备开启通知，接收家庭中所有宠物的照护提醒。',
                  'Enable notifications on this device for all pets in your household.')),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('到时提醒', 'Care reminders')),
                subtitle: Text(reminders.enabled
                    ? t('已开启', 'Enabled')
                    : t('未开启', 'Disabled')),
                value: reminders.enabled,
                onChanged: busy ? null : toggleReminders,
              ),
            ]),
            if (reminderError != null)
              Text(
                  t('提醒设置未完成，请检查系统通知权限后重试。',
                      'Reminder setup failed. Check notification permissions and retry.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Text(t(
                '首次开启时，请在系统弹窗中选择“允许”。如果曾经拒绝，请前往系统设置，允许 petcare 发送通知，再回来打开开关。',
                'Choose Allow in the system prompt. If you previously denied access, allow notifications for petcare in system settings, then enable this switch.')),
          ]);
}

class _CarePage extends StatefulWidget {
  const _CarePage(
      {required this.home, required this.title, required this.content});
  final CareHomeState home;
  final String title;
  final List<Widget> Function(VoidCallback refresh) content;

  @override
  State<_CarePage> createState() => _CarePageState();
}

class _CarePageState extends State<_CarePage> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.home.careChanges,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: SafeArea(
            child: Column(children: [
              if (widget.home.busy) const LinearProgressIndicator(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      children: widget.content(() {
                        if (mounted) setState(() {});
                      }),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}
