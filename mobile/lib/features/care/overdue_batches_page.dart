import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/theme/app_spacing.dart';

/// Paginated personal batch history and resumable result details.
class OverdueBatchesPage extends StatefulWidget {
  const OverdueBatchesPage(
      {super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  @override
  State<OverdueBatchesPage> createState() => _OverdueBatchesPageState();
}

class _OverdueBatchesPageState extends State<OverdueBatchesPage> {
  final items = <Map<String, dynamic>>[];
  bool busy = false, unfinished = true, more = false;
  String cursor = '';
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        items.clear();
        cursor = '';
      }
    });
    try {
      final result = await widget.home.widget.api.request(
          'GET',
          Uri(path: '/care/overdue/batches', queryParameters: {
            'petId': widget.petId,
            'unfinished': '$unfinished',
            'cursor': cursor
          }).toString()) as Map;
      if (!mounted) return;
      setState(() {
        items.addAll((result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map)));
        more = result['hasMore'] == true;
        cursor = result['nextCursor'] as String? ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, dynamic> batch) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OverdueBatchDetailsPage(
            home: widget.home, batchId: batch['id'] as String)));
    if (mounted) await load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('批次管理', 'Batch management'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(children: [
                  Padding(
                      padding: AppSpacing.pageInsets,
                      child: Wrap(spacing: 12, children: [
                        ChoiceChip(
                            label: Text(t('未完成', 'Unfinished')),
                            selected: unfinished,
                            onSelected: busy
                                ? null
                                : (_) {
                                    setState(() => unfinished = true);
                                    load(reset: true);
                                  }),
                        ChoiceChip(
                            label: Text(t('全部批次', 'All batches')),
                            selected: !unfinished,
                            onSelected: busy
                                ? null
                                : (_) {
                                    setState(() => unfinished = false);
                                    load(reset: true);
                                  }),
                      ])),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                        padding: AppSpacing.cardInsets,
                        child: Column(children: [
                          Text(error!),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => load(reset: items.isEmpty),
                              child: Text(t('重新加载', 'Reload')))
                        ])),
                  Expanded(
                      child: RefreshIndicator(
                          onRefresh: () => load(reset: true),
                          child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppSpacing.pageInsets,
                              itemCount: items.length + 1,
                              itemBuilder: (context, index) {
                                if (index == items.length) {
                                  return more
                                      ? TextButton(
                                          onPressed: busy ? null : () => load(),
                                          child: Text(t('加载更多', 'Load more')))
                                      : items.isEmpty && !busy && error == null
                                          ? Text(t(
                                              '没有相关批次', 'No matching batches'))
                                          : const SizedBox.shrink();
                                }
                                final b = items[index];
                                return Card(
                                    child: ListTile(
                                        onTap: () => open(b),
                                        title: Text(batchState(
                                            b['state'] as String, t)),
                                        subtitle: Text(
                                            '${widget.home.dateLabel(DateTime.parse(b['createdAt'] as String).toLocal())}\n${t('共 ${b['total']} 项 · 剩余 ${b['remaining']} 项', '${b['total']} total · ${b['remaining']} remaining')}'),
                                        isThreeLine: true,
                                        trailing:
                                            const Icon(Icons.chevron_right)));
                              }))),
                ]))),
      );
}

String batchState(String state, String Function(String, String) t) =>
    switch (state) {
      'RUNNING' => t('未完成', 'Unfinished'),
      'ENDED' => t('已结束', 'Ended'),
      'COMPLETE' => t('已处理', 'Processed'),
      _ => t('待确认', 'Awaiting confirmation')
    };

class OverdueBatchDetailsPage extends StatefulWidget {
  const OverdueBatchDetailsPage(
      {super.key, required this.home, required this.batchId});
  final CareHomeState home;
  final String batchId;
  @override
  State<OverdueBatchDetailsPage> createState() =>
      _OverdueBatchDetailsPageState();
}

class _OverdueBatchDetailsPageState extends State<OverdueBatchDetailsPage> {
  final items = <Map<String, dynamic>>[];
  Map<String, dynamic>? batch;
  String status = '', cursor = '';
  bool busy = false, writing = false, more = false;
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  String get path => '/care/overdue/batches/${widget.batchId}';
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        items.clear();
        cursor = '';
      }
    });
    try {
      final result = await widget.home.widget.api.request(
          'GET',
          Uri(
                  path: '$path/items',
                  queryParameters: {'status': status, 'cursor': cursor})
              .toString()) as Map;
      if (!mounted) return;
      setState(() {
        batch = Map<String, dynamic>.from(result['batch'] as Map);
        items.addAll((result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map)));
        more = result['hasMore'] == true;
        cursor = result['nextCursor'] as String? ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> operate(String action,
      {List<Map<String, dynamic>>? retry}) async {
    if (writing || busy || !widget.home.can('CARE')) return;
    if (action != 'end' &&
        widget.home.widget.api.offlineCare.pendingCount > 0) {
      setState(() =>
          error = t('请先同步或处理本机待同步操作。', 'Resolve pending local changes first.'));
      return;
    }
    if (action == 'end' &&
        !await widget.home.confirm(
            t('结束这个批次？', 'End this batch?'),
            t('仅停止剩余事项，已成功的跳过记录会保留。剩余照护仍在逾期列表中。',
                'Only remaining work stops. Successful skips are kept. Remaining care stays overdue.'))) {
      return;
    }
    if (!mounted) return;
    setState(() {
      writing = true;
      error = null;
    });
    try {
      if (action == 'retry') {
        batch = Map<String, dynamic>.from(
            await widget.home.widget.api.request('POST', '$path/retry', {
          'items': retry!
              .map((v) => {'id': v['id'], 'attempts': v['attempts']})
              .toList()
        }) as Map);
      } else if (action == 'end') {
        batch = Map<String, dynamic>.from(
            await widget.home.widget.api.request('POST', '$path/end') as Map);
      }
      while (mounted && action != 'end' && batch?['finished'] != true) {
        final result =
            await widget.home.widget.api.request('POST', '$path/apply') as Map;
        if (!mounted) return;
        setState(() => batch = Map<String, dynamic>.from(result));
      }
      if (mounted) {
        await load(reset: true);
        await widget.home.refreshQuietly();
      }
    } catch (e) {
      if (mounted) {
        // Reload persisted state after a lost response; never blindly repeat a retry.
        await load(reset: true);
        if (mounted) {
          setState(() => error = t('操作中断，请重新加载查看已保存的结果；未完成批次可继续处理。',
              'Operation interrupted. Reload saved results; unfinished batches can resume.'));
        }
      }
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  String itemStatus(String value) => switch (value) {
        'SUCCESS' => t('跳过成功', 'Skipped'),
        'FAILED' => t('处理失败', 'Failed'),
        'CHANGED' => t('状态已变化', 'Changed'),
        'STOPPED' => t('未处理 · 批次已结束', 'Not processed · batch ended'),
        _ => t('等待处理', 'Pending')
      };
  String reason(String? value) => switch (value) {
        'INTEGRITY_ERROR' => t('记录保存未通过数据完整性校验，可单独重试；持续失败请联系管理员。',
            'The record could not be saved because of a data integrity conflict. Retry, or contact an administrator if it persists.'),
        'UNAVAILABLE' => t('事项已删除或已不属于当前家庭／宠物。',
            'The reminder was deleted or is no longer accessible.'),
        'REVISION_CHANGED' => t('事项内容已被修改，未覆盖新版本。',
            'The reminder was edited. Its newer version was preserved.'),
        'STATE_CHANGED' => t('事项已完成、跳过或取消。',
            'The reminder was completed, skipped or cancelled.'),
        'DATE_CHANGED' => t('事项时间已变化，不再符合处理范围。',
            'The reminder no longer matches the date range.'),
        'USER_ENDED' => t('你已结束批次，此事项没有被跳过。',
            'The batch was ended. This reminder was not skipped.'),
        _ => '',
      };
  @override
  Widget build(BuildContext context) {
    final locked = writing || busy;
    final failed = items.where((v) => v['status'] == 'FAILED').toList();
    return Scaffold(
        appBar: AppBar(title: Text(t('批量处理详情', 'Batch details'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(children: [
                  if (batch != null)
                    Padding(
                        padding: AppSpacing.cardInsets,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(batchState(batch!['state'] as String, t)),
                              Text(t(
                                  '成功 ${batch!['success']} · 变化 ${batch!['changed']} · 失败 ${batch!['failed']} · 剩余 ${batch!['remaining']} · 未处理 ${batch!['stopped'] ?? 0}',
                                  '${batch!['success']} skipped · ${batch!['changed']} changed · ${batch!['failed']} failed · ${batch!['remaining']} pending · ${batch!['stopped'] ?? 0} stopped')),
                              Wrap(spacing: 12, children: [
                                if (batch!['state'] == 'RUNNING' &&
                                    widget.home.can('CARE')) ...[
                                  FilledButton(
                                      onPressed: locked
                                          ? null
                                          : () => operate('apply'),
                                      child: Text(t('继续处理', 'Resume batch'))),
                                  TextButton(
                                      onPressed:
                                          locked ? null : () => operate('end'),
                                      child: Text(t('结束批次', 'End batch'))),
                                ],
                                if (failed.isNotEmpty &&
                                    batch!['state'] == 'COMPLETE' &&
                                    widget.home.can('CARE'))
                                  TextButton(
                                      onPressed: locked
                                          ? null
                                          : () =>
                                              operate('retry', retry: failed),
                                      child: Text(t('重试本页失败项（${failed.length}）',
                                          'Retry failures on this page (${failed.length})'))),
                              ]),
                            ])),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final code in [
                          '',
                          'SUCCESS',
                          'FAILED',
                          'CHANGED',
                          'PENDING',
                          'STOPPED'
                        ])
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                  label: Text(code.isEmpty
                                      ? t('全部', 'All')
                                      : itemStatus(code)),
                                  selected: status == code,
                                  onSelected: locked
                                      ? null
                                      : (_) {
                                          setState(() => status = code);
                                          load(reset: true);
                                        })),
                      ])),
                  if (locked) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                        padding: AppSpacing.cardInsets,
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  TextButton(
                      onPressed: locked ? null : () => load(reset: true),
                      child: Text(t('重新加载', 'Reload'))),
                  Expanded(
                      child: RefreshIndicator(
                          onRefresh: () =>
                              locked ? Future.value() : load(reset: true),
                          child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppSpacing.pageInsets,
                              itemCount: items.length + 1,
                              itemBuilder: (context, index) {
                                if (index == items.length) {
                                  return more
                                      ? TextButton(
                                          onPressed:
                                              locked ? null : () => load(),
                                          child: Text(t('加载更多', 'Load more')))
                                      : items.isEmpty &&
                                              !locked &&
                                              error == null
                                          ? Text(t(
                                              '没有相关记录', 'No matching records'))
                                          : const SizedBox.shrink();
                                }
                                final row = items[index];
                                return Card(
                                    child: Padding(
                                        padding: AppSpacing.cardInsets,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  row['title'] as String? ??
                                                      t('原事项不可用',
                                                          'Original reminder unavailable'),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium),
                                              if (row['dueAt'] != null)
                                                Text(widget.home.dateLabel(
                                                    DateTime.parse(row['dueAt']
                                                            as String)
                                                        .toLocal())),
                                              Text(itemStatus(
                                                  row['status'] as String)),
                                              if (reason(
                                                      row['reason'] as String?)
                                                  .isNotEmpty)
                                                Text(reason(
                                                    row['reason'] as String?)),
                                              if (row['status'] == 'FAILED' &&
                                                  batch?['state'] ==
                                                      'COMPLETE' &&
                                                  widget.home.can('CARE'))
                                                TextButton(
                                                    key: ValueKey(
                                                        'retry-overdue-${row['id']}'),
                                                    onPressed: locked
                                                        ? null
                                                        : () => operate('retry',
                                                            retry: [row]),
                                                    child: Text(t('重试此项',
                                                        'Retry this item'))),
                                            ])));
                              }))),
                ]))));
  }
}
