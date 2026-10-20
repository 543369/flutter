import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/network/care_api.dart';
import '../../core/theme/app_spacing.dart';
import 'care_pages.dart';
import 'overdue_batches_page.dart';

/// Server-paged backlog. Group selections are scopes, never a list of every ID.
class OverdueCarePage extends StatefulWidget {
  const OverdueCarePage({super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  @override
  State<OverdueCarePage> createState() => _OverdueCarePageState();
}

class _OverdueCarePageState extends State<OverdueCarePage> {
  late final DateTime before =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTimeRange? range;
  String? asOf, error;
  String groupCursor = '';
  bool loading = false,
      writing = false,
      moreGroups = false,
      allRecurring = false;
  int total = 0, recurringTotal = 0, singleTotal = 0;
  final groups = <Map<String, dynamic>>[];
  final rows = <String, List<Map<String, dynamic>>>{};
  final cursors = <String, String>{};
  final more = <String, bool>{};
  final fetching = <String>{}, expanded = <String>{};
  final selectedGroups = <String, Map<String, dynamic>>{};
  final excludedGroups = <String, Map<String, dynamic>>{};
  final excludedItems = <String, String>{};
  final individual = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? job;
  CareHomeState get home => widget.home;
  String t(String z, String e) => home.t(z, e);
  int number(dynamic value) => (value as num? ?? 0).toInt();
  int get selectedCount =>
      (allRecurring
          ? recurringTotal -
              excludedGroups.values
                  .fold<int>(0, (n, g) => n + number(g['count']))
          : selectedGroups.values
              .fold<int>(0, (n, g) => n + number(g['count']))) -
      excludedItems.length +
      individual.length;
  bool whole(String id) =>
      id != 'single' &&
      (allRecurring
          ? !excludedGroups.containsKey(id)
          : selectedGroups.containsKey(id));
  bool selected(Map<String, dynamic> item) =>
      individual.containsKey(item['id']) ||
      (whole(item['planId'] as String? ?? 'single') &&
          !excludedItems.containsKey(item['id']));
  int groupSelected(Map<String, dynamic> group) {
    final id = group['id'] as String;
    return whole(id)
        ? number(group['count']) -
            excludedItems.values.where((v) => v == id).length
        : individual.values.where((v) => v['planId'] == id).length;
  }

  Future<void> openBatches({String? batchId}) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => batchId == null
            ? OverdueBatchesPage(home: home, petId: widget.petId)
            : OverdueBatchDetailsPage(home: home, batchId: batchId)));
    if (mounted) {
      await loadGroups(reset: true);
      await loadJob();
    }
  }

  void clearSelection() {
    allRecurring = false;
    selectedGroups.clear();
    excludedGroups.clear();
    excludedItems.clear();
    individual.clear();
  }

  Map<String, String> params() => {
        'petId': widget.petId,
        'before': before.toUtc().toIso8601String(),
        if (asOf != null) 'asOf': asOf!,
        if (range != null) 'from': range!.start.toUtc().toIso8601String(),
        if (range != null)
          'to': DateTime(range!.end.year, range!.end.month, range!.end.day + 1)
              .toUtc()
              .toIso8601String(),
      };
  Future<dynamic> get(String path, Map<String, String> query) => home.widget.api
      .request('GET', Uri(path: path, queryParameters: query).toString());
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    await loadGroups(reset: true);
    await loadJob();
  }

  String failure(Object e) => e is ApiError
      ? switch (e.code) {
          'BATCH_TOO_LARGE' => t('单批最多处理 5000 项，请缩小日期范围后重试。',
              'A batch can contain at most 5,000 items. Choose a smaller date range.'),
          'OVERDUE_SELECTION_EMPTY' => t('所选事项已变化，没有可跳过的项目，请刷新。',
              'The selection changed. No matching reminders remain. Refresh the list.'),
          'OVERDUE_PREVIEW_EXPIRED' => t('确认已过期，请重新选择并确认。',
              'The preview expired. Select and confirm again.'),
          _ => home.message(e),
        }
      : home.message(e);
  Future<void> loadGroups({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        clearSelection();
        asOf = null;
        groups.clear();
        rows.clear();
        cursors.clear();
        more.clear();
        expanded.clear();
        groupCursor = '';
      }
    });
    try {
      final result = await get(
          '/care/overdue/groups', {...params(), 'cursor': groupCursor});
      if (!mounted) return;
      setState(() {
        total = number(result['total']);
        recurringTotal = number(result['recurringTotal']);
        singleTotal = number(result['singleTotal']);
        asOf = result['asOf'] as String;
        final ids = groups.map((g) => g['id']).toSet();
        groups.addAll((result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .where((g) => !ids.contains(g['id'])));
        moreGroups = result['hasMore'] == true;
        groupCursor = result['nextCursor'] as String? ?? '';
      });
      if (range == null && home.mounted && home.data != null) {
        home.updateUi(() => home.data!['overdueSummary'] = [
              ...(home.data?['overdueSummary'] as List? ?? [])
                  .where((v) => (v as Map)['petId'] != widget.petId),
              {
                'petId': widget.petId,
                'count': total,
                'singleCount': singleTotal
              },
            ]);
      }
      if (reset && singleTotal > 0) await loadItems('single');
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadItems(String groupId) async {
    if (fetching.contains(groupId)) return;
    setState(() => fetching.add(groupId));
    try {
      final result = await get('/care/overdue/items',
          {...params(), 'groupId': groupId, 'cursor': cursors[groupId] ?? ''});
      if (!mounted) return;
      setState(() {
        final existing = rows.putIfAbsent(groupId, () => []);
        final ids = existing.map((v) => v['id']).toSet();
        existing.addAll((result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .where((v) => !ids.contains(v['id'])));
        more[groupId] = result['hasMore'] == true;
        cursors[groupId] = result['nextCursor'] as String? ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => fetching.remove(groupId));
    }
  }

  Future<void> loadJob() async {
    try {
      final result = Map<String, dynamic>.from(
          await get('/care/overdue/batches/current', {'petId': widget.petId})
              as Map);
      if (mounted) setState(() => job = result.isEmpty ? null : result);
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    }
  }

  void toggleGroup(Map<String, dynamic> group) {
    final id = group['id'] as String;
    if (!whole(id) && !allRecurring && selectedGroups.length >= 100) {
      setState(() => error = t('一次最多选择 100 个重复计划，请缩小范围。',
          'Select at most 100 recurring plans per batch.'));
      return;
    }
    if (whole(id) && allRecurring && excludedGroups.length >= 100) {
      setState(() => error = t('排除的计划过多，请改用日期范围或逐组选择。',
          'Too many excluded groups. Choose dates or select groups individually.'));
      return;
    }
    setState(() {
      final was = groupSelected(group) == number(group['count']);
      individual.removeWhere((_, v) => v['planId'] == id);
      excludedItems.removeWhere((_, value) => value == id);
      if (allRecurring) {
        if (was) {
          excludedGroups[id] = group;
        } else {
          excludedGroups.remove(id);
        }
      } else {
        if (was) {
          selectedGroups.remove(id);
        } else {
          selectedGroups[id] = group;
        }
      }
    });
  }

  void toggleItem(Map<String, dynamic> item) {
    final id = item['id'] as String,
        group = item['planId'] as String? ?? 'single';
    if (!selected(item) && !whole(group) && individual.length >= 1000) {
      setState(() => error = t('逐项选择最多 1000 项，请使用按组选择。',
          'Select at most 1,000 individual reminders. Use group selection.'));
      return;
    }
    if (selected(item) && whole(group) && excludedItems.length >= 1000) {
      setState(() => error = t('排除事项过多，请缩小日期范围。',
          'Too many exclusions. Choose a smaller date range.'));
      return;
    }
    setState(() {
      if (whole(group)) {
        if (excludedItems.containsKey(id)) {
          excludedItems.remove(id);
        } else {
          excludedItems[id] = group;
        }
      } else {
        if (individual.containsKey(id)) {
          individual.remove(id);
        } else {
          individual[id] = item;
        }
      }
    });
  }

  Future<void> chooseRange() async {
    final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: before.subtract(const Duration(days: 1)),
        initialDateRange: range,
        helpText: t('选择要处理的逾期日期范围', 'Choose overdue dates'));
    if (selected == null || !mounted) return;
    setState(() => range = selected);
    await loadGroups(reset: true);
  }

  Future<void> details(Map<String, dynamic> task) async {
    home.updateUi(() => home.data?['tasks'] = [
          ...home.tasks.where((v) => v['id'] != task['id']),
          task
        ]);
    await home.openTaskDetails(task);
    if (mounted) await loadGroups(reset: true);
  }

  Future<void> startBatch() async {
    if (writing || selectedCount <= 0) return;
    if (selectedCount > 5000) {
      setState(() => error = t('已选超过 5000 项，请缩小日期范围。',
          'More than 5,000 selected. Choose a smaller date range.'));
      return;
    }
    if (home.widget.api.offlineCare.pendingCount > 0) {
      setState(() => error = t('请先同步或处理本机待同步操作，再批量跳过。',
          'Resolve pending local changes before running a batch.'));
      return;
    }
    setState(() {
      writing = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{
        ...params(),
        'allRecurring': allRecurring,
        'groupIds': selectedGroups.keys.toList(),
        'excludedGroups': excludedGroups.keys.toList(),
        'excludedIds': excludedItems.keys.toList(),
        'items': individual.values
            .map((v) => {'id': v['id'], 'revision': v['revision']})
            .toList(),
      };
      final preview = Map<String, dynamic>.from(await home.widget.api
          .request('POST', '/care/overdue/preview', body) as Map);
      if (!mounted) return;
      final count = number(preview['total']);
      if (!await home.confirm(
              t('跳过选中的 $count 项照护？', 'Skip $count selected reminders?'),
              t('此数量已由服务器核对。仅处理当前选择，保留跳过记录，不计为完成，后续重复安排不变。已修改的事项不会被覆盖。',
                  'The server verified this count. History is kept, skipped items do not count as completed, and future care stays. Changed reminders will not be overwritten.')) ||
          !mounted) {
        return;
      }
      setState(() => job = {...preview, 'state': 'RUNNING'});
      await applyJob();
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  Future<void> applyJob() async {
    try {
      while (mounted && job != null && job!['finished'] != true) {
        final result = Map<String, dynamic>.from(await home.widget.api.request(
            'POST', '/care/overdue/batches/${job!['id']}/apply') as Map);
        if (!mounted) return;
        setState(() => job = result);
      }
      if (mounted) {
        await loadGroups(reset: true);
        await home.refreshQuietly();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = t('处理暂时中断，已成功的操作会保留。点击继续处理，不会重复写入。',
            'Processing paused. Successful changes are saved. Resume safely without duplicate events.'));
      }
    }
  }

  Future<void> resume() async {
    if (writing || !home.can('CARE')) return;
    if (home.widget.api.offlineCare.pendingCount > 0) {
      setState(() =>
          error = t('请先同步或处理本机待同步操作。', 'Resolve pending local changes first.'));
      return;
    }
    setState(() {
      writing = true;
      error = null;
    });
    try {
      await applyJob();
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  String day(dynamic value) {
    final date = DateTime.parse(value as String).toLocal();
    return '${date.month}/${date.day}';
  }

  List<Widget> itemWidgets(String id) => [
        for (final task in rows[id] ?? <Map<String, dynamic>>[])
          CheckboxListTile(
            key: ValueKey('overdue-item-${task['id']}'),
            value: selected(task),
            onChanged: writing ? null : (_) => toggleItem(task),
            title: Text(task['title'] as String),
            subtitle: Text(home
                .dateLabel(DateTime.parse(task['dueAt'] as String).toLocal())),
            secondary: IconButton(
                tooltip: t('查看详情', 'View details'),
                icon: const Icon(Icons.chevron_right),
                onPressed: writing ? null : () => details(task)),
          ),
        if (fetching.contains(id)) const LinearProgressIndicator(),
        if (!fetching.contains(id) &&
            (more[id] == true || !rows.containsKey(id)))
          TextButton(
              onPressed: writing ? null : () => loadItems(id),
              child: Text(t('加载更多', 'Load more'))),
      ];
  Widget groupCard(Map<String, dynamic> group) {
    final id = group['id'] as String;
    return Card(
        child: ExpansionTile(
      key: ValueKey('overdue-group-$id-$asOf'),
      initiallyExpanded: expanded.contains(id),
      leading: Checkbox(
          key: ValueKey('select-overdue-group-$id'),
          tristate: true,
          value: groupSelected(group) == 0
              ? false
              : groupSelected(group) == number(group['count'])
                  ? true
                  : null,
          onChanged: writing ? null : (_) => toggleGroup(group)),
      title: Text(group['title'] as String),
      subtitle: Text(t(
          '逾期 ${group['count']} 次 · ${day(group['firstAt'])}—${day(group['lastAt'])}',
          '${group['count']} overdue · ${day(group['firstAt'])}–${day(group['lastAt'])}')),
      onExpansionChanged: (open) {
        if (open) {
          expanded.add(id);
          if (!rows.containsKey(id)) loadItems(id);
        } else {
          expanded.remove(id);
        }
      },
      children: [
        TextButton(
            onPressed: writing ? null : () => toggleGroup(group),
            child: Text(groupSelected(group) == number(group['count'])
                ? t('取消本组全选', 'Deselect group')
                : t('本组全选', 'Select entire group'))),
        ...itemWidgets(id),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('逾期事项', 'Overdue care')), actions: [
          TextButton(
              onPressed: writing ? null : () => openBatches(),
              child: Text(t('批次管理', 'Batches')))
        ]),
        body: RefreshIndicator(
          onRefresh: () => writing ? Future.value() : loadGroups(reset: true),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView.builder(
              padding: AppSpacing.pageInsets,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: groups.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t(
                            '共 $total 项逾期 · 重复 $recurringTotal 项 · 单次 $singleTotal 项',
                            '$total overdue · $recurringTotal recurring · $singleTotal one-off')),
                        const SizedBox(height: AppSpacing.item),
                        Text(t('重复计划默认折叠；单次用药、就诊等重要事项需逐项确认。跳过不计为完成。',
                            'Recurring plans start collapsed. Select one-off medical reminders individually. Skipping does not count as completion.')),
                        const SizedBox(height: AppSpacing.item),
                        Wrap(
                            spacing: AppSpacing.inline,
                            runSpacing: AppSpacing.inline,
                            children: [
                              OutlinedButton.icon(
                                  onPressed:
                                      writing || loading ? null : chooseRange,
                                  icon: const Icon(Icons.date_range),
                                  label: Text(range == null
                                      ? t('选择日期范围', 'Choose dates')
                                      : '${day(range!.start.toIso8601String())}—${day(range!.end.toIso8601String())}')),
                              if (range != null)
                                TextButton(
                                    onPressed: writing || loading
                                        ? null
                                        : () {
                                            setState(() => range = null);
                                            loadGroups(reset: true);
                                          },
                                    child: Text(t('全部日期', 'All dates'))),
                              OutlinedButton(
                                  onPressed:
                                      writing || loading || recurringTotal == 0
                                          ? null
                                          : () {
                                              setState(() {
                                                clearSelection();
                                                allRecurring = true;
                                              });
                                            },
                                  child: Text(
                                      t('只选重复事项', 'Select recurring only'))),
                              if (selectedCount > 0)
                                TextButton(
                                    onPressed: writing
                                        ? null
                                        : () => setState(clearSelection),
                                    child: Text(t('清空选择', 'Clear selection'))),
                            ]),
                        if (selectedCount > 5000)
                          Padding(
                              padding: AppSpacing.cardInsets,
                              child: Text(
                                  t('已选 $selectedCount 项，单批最多 5000 项。请缩小日期范围后处理。',
                                      '$selectedCount selected. The limit is 5,000 per batch. Choose a smaller date range.'),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        if (loading) const LinearProgressIndicator(),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.item),
                              child: Text(error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        if (error != null)
                          TextButton(
                              onPressed: writing || loading ? null : initialize,
                              child: Text(t('重新加载', 'Reload'))),
                        if (job != null && job!['state'] != 'PREVIEW')
                          Card(
                              child: Padding(
                                  padding: AppSpacing.cardInsets,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t(
                                            '跳过成功 ${job!['success']} 项 · 状态已变化 ${job!['changed']} 项 · 失败 ${job!['failed']} 项',
                                            '${job!['success']} skipped · ${job!['changed']} changed · ${job!['failed']} failed')),
                                        TextButton(
                                            onPressed: writing
                                                ? null
                                                : () => openBatches(
                                                    batchId:
                                                        job!['id'] as String),
                                            child: Text(
                                                t('查看处理详情', 'View results'))),
                                        if (job!['finished'] != true)
                                          Text(t(
                                              '剩余 ${job!['remaining']} 项，可继续处理。',
                                              '${job!['remaining']} remaining. Resume to continue.')),
                                      ]))),
                        const SizedBox(height: AppSpacing.item),
                      ]);
                }
                if (index <= groups.length) return groupCard(groups[index - 1]);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (moreGroups)
                        TextButton(
                            onPressed:
                                loading || writing ? null : () => loadGroups(),
                            child: Text(
                                t('加载更多重复计划', 'Load more recurring plans'))),
                      if (singleTotal > 0) ...[
                        const SizedBox(height: AppSpacing.item),
                        Text(
                            t('单次重要事项 · $singleTotal',
                                'One-off reminders · $singleTotal'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.inline),
                        Card(child: Column(children: itemWidgets('single'))),
                      ],
                      if (!loading && total == 0)
                        Padding(
                            padding: AppSpacing.cardInsets,
                            child: Text(t('没有逾期事项', 'No overdue care'))),
                    ]);
              },
            ),
          )),
        ),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Material(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.content),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('已选 ${selectedCount.clamp(0, 999999)} 项',
                                '${selectedCount.clamp(0, 999999)} selected')),
                            if (job != null && job!['state'] != 'PREVIEW')
                              Text(
                                  job!['finished'] == true
                                      ? t('成功 ${job!['success']} · 变化 ${job!['changed']} · 失败 ${job!['failed']}',
                                          '${job!['success']} skipped · ${job!['changed']} changed · ${job!['failed']} failed')
                                      : t('已处理 ${number(job!['total']) - number(job!['remaining'])}/${job!['total']}',
                                          '${number(job!['total']) - number(job!['remaining'])}/${job!['total']} processed'),
                                  style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                    const SizedBox(width: AppSpacing.item),
                    FilledButton(
                        onPressed: writing || loading || !home.can('CARE')
                            ? null
                            : job != null &&
                                    job!['finished'] != true &&
                                    job!['state'] != 'PREVIEW'
                                ? resume
                                : selectedCount > 0 &&
                                        selectedCount <= 5000 &&
                                        home.can('CARE')
                                    ? startBatch
                                    : null,
                        child: Text(writing
                            ? t('正在处理…', 'Processing…')
                            : job != null &&
                                    job!['finished'] != true &&
                                    job!['state'] != 'PREVIEW'
                                ? t('继续处理', 'Resume')
                                : t('标记跳过', 'Skip selected'))),
                  ]),
                ))),
      );
}
