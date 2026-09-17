import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import 'care_actions.dart';
import 'care_pages.dart';
import 'care_view.dart';
import 'care_kind.dart';

class CareSchedulePage extends StatefulWidget {
  const CareSchedulePage(
      {super.key, required this.home, required this.initialFilter});
  final CareHomeState home;
  final String initialFilter;
  @override
  State<CareSchedulePage> createState() => _CareSchedulePageState();
}

class _CareSchedulePageState extends State<CareSchedulePage> {
  late String filter = widget.initialFilter;
  late String? petId = widget.home.selectedPet?['id'] as String?;
  List<Map<String, dynamic>> items = [];
  bool loading = false, more = false;
  String? error;
  int offset = 0;
  String t(String z, String e) => widget.home.t(z, e);
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (loading || filter == 'recurring' || petId == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.home.widget.api.request('GET',
          '/tasks?petId=$petId&state=$filter&offset=${reset ? 0 : offset}');
      if (!mounted) return;
      final next = (result['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      // List results also make old completed/cancelled tasks available to details.
      final ids = next.map((v) => v['id']).toSet();
      widget.home.updateUi(() => widget.home.data = {
            ...widget.home.data!,
            'tasks': [
              ...widget.home.tasks.where((v) => !ids.contains(v['id'])),
              ...next
            ]
          });
      setState(() {
        if (reset) {
          items = [];
          offset = 0;
        }
        final existing = items.map((v) => v['id']).toSet();
        items.addAll(next.where((v) => !existing.contains(v['id'])));
        offset += next.length;
        more = result['hasMore'] as bool;
      });
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    await widget.home.addTask();
    if (!mounted) return;
    petId = widget.home.selectedPet?['id'] as String?;
    if (filter != 'recurring') filter = 'pending';
    setState(() {});
    await load(reset: true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.home.careChanges,
      builder: (context, _) {
        final home = widget.home;
        final rows = items
            .map((v) =>
                home.tasks.where((v2) => v2['id'] == v['id']).firstOrNull ?? v)
            .where((v) => switch (filter) {
                  'pending' => v['completed'] != true &&
                      v['cancelled'] != true &&
                      v['skipped'] != true,
                  'completed' => v['completed'] == true,
                  'inactive' => v['cancelled'] == true || v['skipped'] == true,
                  _ => false,
                })
            .toList();
        final plans = home.plans.where((v) => v['petId'] == petId).toList();
        final pet = home.pets.where((v) => v['id'] == petId).firstOrNull;
        return Scaffold(
            appBar: AppBar(title: Text(t('全部安排', 'All plans'))),
            body: RefreshIndicator(
                onRefresh: () => load(reset: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(t('${pet?['name'] ?? '宠物'}的照护安排',
                        'Care for ${pet?['name'] ?? 'your pet'}')),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        key: const ValueKey('create-schedule'),
                        onPressed: home.busy || loading ? null : create,
                        icon: const Icon(Icons.add),
                        label: Text(t('新建安排', 'New plan'))),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, children: [
                      for (final entry in {
                        'pending': t('待照护', 'Pending'),
                        'completed': t('已完成', 'Completed'),
                        'recurring': t('重复计划', 'Recurring'),
                        'inactive': t('已取消/跳过', 'Cancelled / skipped')
                      }.entries)
                        ChoiceChip(
                            label: Text(entry.value),
                            selected: filter == entry.key,
                            onSelected: loading
                                ? null
                                : (_) {
                                    setState(() {
                                      filter = entry.key;
                                      items = [];
                                      error = null;
                                      more = false;
                                    });
                                    load(reset: true);
                                  })
                    ]),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null) ...[
                      Text(error!),
                      TextButton(
                          onPressed:
                              loading ? null : () => load(reset: items.isEmpty),
                          child: Text(t('重试', 'Retry')))
                    ],
                    if (filter == 'recurring') ...[
                      if (plans.isEmpty)
                        home.empty(
                            t('还没有重复计划', 'No recurring plans'),
                            t('点击新建安排，选择每天或每周。',
                                'Create a plan and choose daily or weekly.'),
                            Icons.repeat),
                      for (final plan in plans)
                        Card(
                            child: ListTile(
                                leading: CareKind.of(plan).picture(size: 52),
                                title: Text(plan['title'] as String),
                                subtitle: Text(home.frequencyLabel(plan)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => home.openPlanDetails(plan))),
                    ] else ...[
                      if (rows.isEmpty && !loading && error == null)
                        home.empty(
                            t(
                                '暂无此类安排',
                                filter == 'completed'
                                    ? 'No completed plans'
                                    : 'No pending plans'),
                            t('随时可以新建照护安排。',
                                'Create care whenever you need it.'),
                            Icons.event_available),
                      for (final task in rows)
                        Card(
                            child: ListTile(
                                leading: filter == 'completed'
                                    ? Checkbox(
                                        value: true,
                                        onChanged:
                                            home.taskBusy(task['id'] as String)
                                                ? null
                                                : (_) => home.changeCompletion(
                                                    task, false))
                                    : CareKind.of(task).picture(size: 44),
                                title: Text(task['title'] as String),
                                subtitle: Text(
                                    '${home.dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())}\n${task['petName']} · ${task['skipped'] == true ? t('已跳过', 'Skipped') : task['cancelled'] == true ? t('已取消', 'Cancelled') : home.frequencyLabel(home.planFor(task))}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => home.openTaskDetails(task))),
                      if (more && !loading)
                        TextButton(
                            onPressed: () => load(),
                            child: Text(t('加载更多', 'Load more'))),
                    ],
                  ],
                )));
      });
}
