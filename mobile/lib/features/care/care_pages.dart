import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  String eventAction(Map<String, dynamic> event) => switch (event['action']) {
        'REOPENED' => t('已撤销完成', 'Completion undone'),
        'SKIPPED' => t('已跳过', 'Skipped'),
        'CANCELLED' => t('已取消', 'Cancelled'),
        'RESCHEDULED' => t('已调整时间', 'Rescheduled'),
        _ => t('已完成照护', 'Care completed'),
      };

  Future<void> _openCarePage(
      String title, List<Widget> Function(VoidCallback refresh) content) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _CarePage(home: this, title: title, content: content)));
  }

  Widget _detailField(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.inline),
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
          padding: AppSpacing.cardInsets,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      );

  Widget _sectionTitle(String title, {bool afterCard = false}) => Padding(
      padding: EdgeInsets.only(
          top: afterCard ? AppSpacing.item : AppSpacing.section,
          bottom: AppSpacing.item),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge));

  Widget _scheduleCard(Map<String, dynamic> task, {VoidCallback? onOpen}) =>
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.content, vertical: AppSpacing.inline),
          leading: CareKind.of(task).picture(size: 52),
          title: Text(task['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())}\n'
              '${task['petName']} · ${frequencyLabel(planFor(task))}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpen ?? () => openTaskDetails(task),
        ),
      );

  Future<void> openSchedules() => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _SchedulesPage(home: this)));

  Future<void> openCareArchive({bool events = false}) async {
    final petId = selectedPet?['id'];
    final entries = <Map<String, dynamic>>[];
    bool more = true, fetching = false;
    String? failure;
    String cursor = '';
    Future<void> load(VoidCallback refresh, {bool reset = false}) async {
      if (fetching) return;
      fetching = true;
      refresh();
      try {
        final result = await widget.api.request('GET',
            '/${events ? 'care-history' : 'tasks'}?petId=$petId&cursor=${Uri.encodeQueryComponent(reset ? "" : cursor)}');
        if (reset) entries.clear();
        final incoming = (result['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final ids = incoming.map((e) => e['id']).toSet();
        entries.removeWhere((e) => ids.contains(e['id']));
        entries.addAll(incoming);
        cursor = result['nextCursor'] as String? ?? '';
        more = result['hasMore'] == true;
        failure = null;
        if (!events && mounted) {
          updateUi(() {
            final loadedIds = entries.map((e) => e['id']).toSet();
            data?['tasks'] = [
              ...tasks.where((t) => !loadedIds.contains(t['id'])),
              ...entries
            ];
          });
        }
      } catch (e) {
        failure = message(e);
      } finally {
        fetching = false;
        refresh();
      }
    }

    await load(() {});
    if (!mounted) return;
    await _openCarePage(
        t(events ? '全部照护记录' : '全部照护安排',
            events ? 'All care history' : 'All care plans'),
        (refresh) => [
              for (final entry in entries)
                events
                    ? _historyLink(entry)
                    : _scheduleCard(
                        tasks
                                .where((t) => t['id'] == entry['id'])
                                .firstOrNull ??
                            entry, onOpen: () async {
                        await openTaskDetails(entry);
                        if (mounted) await load(refresh, reset: true);
                      }),
              if (failure != null) Text(failure!),
              if (more)
                TextButton(
                    onPressed: fetching ? null : () => load(refresh),
                    child: Text(t(fetching ? '正在加载' : '加载更多',
                        fetching ? 'Loading' : 'Load more'))),
              if (entries.isEmpty && !more) Text(t('暂无记录', 'No records yet')),
            ]);
  }

  Future<void> assignCare(Map<String, dynamic> task) async {
    final selected = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
                title: Text(t('指定照护人', 'Assign caregiver')),
                children: [
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(c, ''),
                      child: Text(t('暂不指定', 'Unassigned'))),
                  for (final member in data?['memberProfiles'] as List? ?? [])
                    SimpleDialogOption(
                        onPressed: () =>
                            Navigator.pop(c, member['id'] as String),
                        child: Text(member['name'] as String)),
                ]));
    if (selected != null && mounted) {
      await perform(() async {
        await widget.api.request('PATCH', '/tasks/${task['id']}/assignment',
            {'memberId': selected.isEmpty ? null : selected});
      });
    }
  }

  Future<void> adjustCareTime(Map<String, dynamic> task,
      {bool futurePlan = false}) async {
    if (futurePlan &&
        !await confirm(
            t('调整后续重复时间？', 'Change future recurring care?'),
            t('保留已完成和已逾期事项；尚未到时的旧安排将取消，并从你选择的时间重新生成。',
                'Completed and overdue care stays. Future pending occurrences are replaced starting at your chosen time.'))) {
      return;
    }
    if (!mounted) return;
    final now = DateTime.now();
    final old = DateTime.parse(task['dueAt'] as String).toLocal();
    final day = await showDatePicker(
        context: context,
        initialDate: old.isBefore(now) ? now : old,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: futurePlan
            ? now.add(const Duration(days: 29))
            : DateTime(2037, 12, 31));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(old));
    if (time == null || !mounted) return;
    final due = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!due.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('请选择未来时间', 'Choose a future time'))));
      return;
    }
    await perform(() async {
      await widget.api.request(
          'PATCH',
          futurePlan
              ? '/plans/${task['planId']}/future'
              : '/tasks/${task['id']}/time',
          {
            'dueAt': due.toUtc().toIso8601String(),
            if (futurePlan) 'frequency': planFor(task)?['frequency'],
            if (futurePlan) 'zoneId': planFor(task)?['zoneId'],
          });
    });
  }

  Future<void> dismissCare(Map<String, dynamic> task, String action) async {
    if (!await confirm(
        t(action == 'SKIPPED' ? '跳过本次照护？' : '取消本次安排？',
            'Remove this occurrence?'),
        t('仅影响本次，保留记录，不计为完成。重复计划的后续安排不变。',
            'Only this occurrence changes. History is kept; it does not count as completed.'))) {
      return;
    }
    await perform(() async {
      await widget.api
          .request('POST', '/tasks/${task['id']}/dismiss', {'action': action});
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
        final cancelled = task['cancelled'] == true;
        final taskBusy = busy || submittingTasks.contains(task['id']);
        return [
          CareKind.of(task).picture(size: 148),
          const SizedBox(height: AppSpacing.content),
          _detailCard([
            Text(task['title'] as String,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.item),
            _detailField(t('宠物', 'Pet'), task['petName'] as String),
            _detailField(
                t('负责照护', 'Assigned caregiver'),
                (data?['memberProfiles'] as List? ?? [])
                        .where((m) => m['id'] == task['assignedTo'])
                        .firstOrNull?['name'] as String? ??
                    t('尚未指定', 'Unassigned')),
            _detailField(t('安排时间', 'Scheduled'),
                dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())),
            _detailField(t('照护类型', 'Care type'), CareKind.of(task).label(zh)),
            _detailField(t('重复', 'Repeat'), frequencyLabel(plan)),
            _detailField(
                t('状态', 'Status'),
                cancelled
                    ? t('已取消或跳过', 'Cancelled or skipped')
                    : completed
                        ? t('已完成', 'Completed')
                        : t('待照护', 'Pending')),
          ]),
          if (task['lastEvent'] is Map)
            Text(
                '${task['lastEvent']['actor'] ?? ''} · ${dateLabel(DateTime.parse(task['lastEvent']['at'] as String).toLocal())}'),
          if (!cancelled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.item,
              children: [
                OutlinedButton.icon(
                    onPressed: taskBusy ? null : () => assignCare(task),
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: Text(t('指定照护人', 'Assign caregiver'))),
                FilledButton.icon(
                  onPressed: taskBusy
                      ? null
                      : () => changeCompletion(task, !completed),
                  icon: Icon(completed
                      ? Icons.undo_rounded
                      : Icons.check_circle_rounded),
                  label: Text(submittingTasks.contains(task['id'])
                      ? t('正在保存…', 'Saving…')
                      : completed
                          ? t('撤销完成', 'Undo completion')
                          : t('标记完成', 'Mark as done')),
                ),
                if (!completed) ...[
                  OutlinedButton.icon(
                      onPressed: taskBusy ? null : () => adjustCareTime(task),
                      icon: const Icon(Icons.schedule),
                      label: Text(t('修改本次时间', 'Reschedule this occurrence'))),
                  if (plan != null && plan['active'] == true)
                    TextButton(
                        onPressed: taskBusy
                            ? null
                            : () => adjustCareTime(task, futurePlan: true),
                        child: Text(
                            t('调整后续重复时间', 'Change future recurring time'))),
                  Row(children: [
                    Expanded(
                        child: TextButton(
                            onPressed: taskBusy
                                ? null
                                : () => dismissCare(task, 'SKIPPED'),
                            child: Text(t('跳过本次', 'Skip once')))),
                    Expanded(
                        child: TextButton(
                            onPressed: taskBusy
                                ? null
                                : () => dismissCare(task, 'CANCELLED'),
                            child: Text(t('取消本次', 'Cancel once')))),
                  ]),
                ],
                if (plan != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => openPlanDetails(plan),
                    icon: const Icon(Icons.repeat_rounded),
                    label: Text(t('查看重复计划', 'View recurring plan')),
                  ),
                ],
              ],
            ),
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
          const SizedBox(height: AppSpacing.content),
          _detailCard([
            Text(event['title'] as String,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.item),
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
            const SizedBox(height: AppSpacing.item),
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
          _sectionTitle(t('关联安排', 'Scheduled care'), afterCard: true),
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
              const SizedBox(height: AppSpacing.content),
              Text(t('照护时间到了，提醒你', 'A reminder when care is due'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.inline),
              Text(t('为这台设备开启通知，接收家庭中所有宠物的照护提醒。',
                  'Enable notifications on this device for all pets in your household.')),
              const SizedBox(height: AppSpacing.item),
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
                      padding: AppSpacing.pageInsets,
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

class _SchedulesPage extends StatefulWidget {
  const _SchedulesPage({required this.home});
  final CareHomeState home;
  @override
  State<_SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<_SchedulesPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  final createKey = GlobalKey();
  bool creating = false;

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (creating) return;
    final box = createKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(box.size.center(Offset.zero));
    final existing = widget.home.tasks.map((task) => task['id']).toSet();
    setState(() => creating = true);
    try {
      await widget.home.addTask(revealOrigin: origin);
      if (!mounted) return;
      final created = widget.home.tasks
          .where((task) => !existing.contains(task['id']))
          .firstOrNull;
      if (created != null) {
        tabs.animateTo(created['planId'] == null ? 0 : 2,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260));
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
        listenable: home.careChanges,
        builder: (context, _) {
          final petId = home.selectedPet?['id'];
          final tasks = home.tasks
              .where(
                  (task) => task['petId'] == petId && task['cancelled'] != true)
              .toList()
            ..sort((a, b) => DateTime.parse(a['dueAt'] as String)
                .compareTo(DateTime.parse(b['dueAt'] as String)));
          final plans =
              home.plans.where((plan) => plan['petId'] == petId).toList();
          Widget page(int index) {
            final visible = tasks
                .where((task) => (task['completed'] == true) == (index == 1))
                .toList();
            return ListView(
              key: PageStorageKey('schedules-$petId-$index'),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.section, AppSpacing.page, 104),
              children: index == 2
                  ? [
                      if (plans.isEmpty)
                        home.empty(
                            home.t('还没有重复计划', 'No recurring plans'),
                            home.t('点击右下角新建安排，选择每天或每周。',
                                'Use New plan and choose daily or weekly.'),
                            Icons.repeat_rounded),
                      for (final plan in plans)
                        Card(
                            child: ListTile(
                          leading: CareKind.of(plan).picture(size: 52),
                          title: Text(plan['title'] as String),
                          subtitle: Text(
                              '${home.frequencyLabel(plan)} · ${plan['active'] == true ? home.t('进行中', 'Active') : home.t('已停止', 'Stopped')}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => home.openPlanDetails(plan),
                        )),
                    ]
                  : [
                      if (visible.isEmpty)
                        home.empty(
                            index == 1
                                ? home.t('还没有已完成安排', 'No completed plans')
                                : home.t('还没有待照护安排', 'No pending plans'),
                            home.t('点击右下角按钮新建安排。',
                                'Use the floating button to plan care.'),
                            Icons.event_available_rounded),
                      ...visible.map(home._scheduleCard),
                    ],
            );
          }

          return Scaffold(
            appBar: AppBar(title: Text(home.t('全部安排', 'All plans'))),
            floatingActionButton: FloatingActionButton(
              key: createKey,
              heroTag: null,
              onPressed: home.busy || creating ? null : create,
              shape: const CircleBorder(),
              tooltip: home.t('新建安排', 'New plan'),
              child: const Icon(Icons.add_rounded,
                  key: ValueKey('create-schedule')),
            ),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                        AppSpacing.content, AppSpacing.page, 0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(home.t(
                              '${home.selectedPet?['name'] ?? '宠物'}的照护安排',
                              'Care for ${home.selectedPet?['name'] ?? 'your pet'}')),
                          const SizedBox(height: AppSpacing.inline),
                          TextButton(
                              onPressed: () => home.openCareArchive(),
                              child: Text(
                                  home.t('查看全部日期的安排', 'Browse all dates'))),
                          const SizedBox(height: AppSpacing.content),
                          AnimatedBuilder(
                            animation: tabs,
                            builder: (context, _) =>
                                CupertinoSlidingSegmentedControl<int>(
                              key: ValueKey(reduced ? tabs.index : -1),
                              groupValue: tabs.index,
                              backgroundColor: const Color(0xfff1eae2),
                              thumbColor: const Color(0xfffffdf9),
                              proportionalWidth: false,
                              onValueChanged: (index) {
                                if (index != null) {
                                  tabs.animateTo(index,
                                      duration: reduced
                                          ? Duration.zero
                                          : const Duration(milliseconds: 260));
                                }
                              },
                              children: {
                                for (final entry in <int, String>{
                                  0: home.t('待照护', 'Pending'),
                                  1: home.t('已完成', 'Completed'),
                                  2: home.t('重复计划', 'Recurring'),
                                }.entries)
                                  entry.key: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.inline),
                                    child: Text(entry.value,
                                        style: TextStyle(
                                            color: const Color(0xff5b3b2e),
                                            fontSize: 14,
                                            fontWeight: tabs.index == entry.key
                                                ? FontWeight.w600
                                                : FontWeight.w400)),
                                  ),
                              },
                            ),
                          ),
                        ])),
                Expanded(
                    child: TabBarView(
                        controller: tabs,
                        physics: reduced
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        children: [page(0), page(1), page(2)])),
              ]),
            ))),
          );
        });
  }
}
