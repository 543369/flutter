import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import '../health/health_pages.dart' show healthDay;

const roleNames = {
  'ADMIN': ('管理员', 'Administrator'),
  'MEMBER': ('家庭成员', 'Member'),
  'TEMP': ('临时照护者', 'Temporary caregiver')
};
const permissionNames = {
  'CARE': ('照护操作', 'Care tasks'),
  'HEALTH': ('健康档案', 'Health records'),
  'MEMORIES': ('回忆录', 'Memories'),
  'PETS': ('宠物管理', 'Manage pets'),
  'REPORTS': ('统计与导出', 'Reports and exports')
};

class HouseholdMembersPage extends StatefulWidget {
  const HouseholdMembersPage({super.key, required this.home});
  final CareHomeState home;
  @override
  State<HouseholdMembersPage> createState() => _HouseholdMembersPageState();
}

class _HouseholdMembersPageState extends State<HouseholdMembersPage> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  String t(String z, String e) => widget.home.t(z, e);
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
      final r = await widget.home.widget.api.request('GET', '/family/members');
      if (mounted) setState(() => data = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? member]) async {
    await showDialog<bool>(
        context: context,
        builder: (_) => _RoleEditor(
            home: widget.home,
            member: member,
            advanced: data!['advanced'] as bool));
    if (mounted) {
      await load();
      await widget.home.perform(() async {});
    }
  }

  Future<void> leave() async {
    if (!await widget.home.confirm(
            t('退出当前家庭？', 'Leave this household?'),
            t('共享宠物和记录留在原家庭，你将拥有一个新的空家庭。',
                'Shared pets and records stay with this home. You will get a new empty household.')) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.home.widget.api.request('POST', '/family/leave');
      await widget.home.perform(() async {});
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
      appBar: AppBar(title: Text(t('家人与照护权限', 'People and permissions'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: const Color(0xffe4edf5),
                        borderRadius: BorderRadius.circular(28)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.diversity_1_outlined, size: 36),
                          const SizedBox(height: 12),
                          Text(
                              t('安心托付，一起照顾。',
                                  'Share the care, with confidence.'),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 10),
                          Text(t('管理员管理家人；家庭成员共同照护；临时照护者按授权与到期时间访问。',
                              'Admins manage access. Members share care. Temporary caregivers have limited, expiring access.'))
                        ])),
                const SizedBox(height: 20),
                if (busy) const LinearProgressIndicator(),
                if (error != null) ...[
                  Text(error!),
                  TextButton(
                      onPressed: busy ? null : load,
                      child: Text(t('重试', 'Retry')))
                ],
                if (data != null) ...[
                  for (final raw in data!['items'] as List)
                    Builder(builder: (context) {
                      final m = Map<String, dynamic>.from(raw as Map);
                      final role = roleNames[m['role']]!;
                      final expires =
                          DateTime.tryParse(m['expiresAt'] as String? ?? '');
                      return Card(
                          color: const Color(0xfffff0dc),
                          child: ListTile(
                              contentPadding: const EdgeInsets.all(18),
                              leading: Icon(m['role'] == 'ADMIN'
                                  ? Icons.shield_outlined
                                  : Icons.person_outline),
                              title: Text(
                                  '${m['name']}${m['isMe'] == true ? t('（我）', ' (me)') : ''}'),
                              subtitle: Text(
                                  '${t(role.$1, role.$2)}${expires == null ? '' : '\n${t('到期', 'Expires')}: ${expires.toLocal().toString().substring(0, 16)}${expires.isBefore(DateTime.now()) ? t(' · 已到期', ' · Expired') : ''}'}\n${(m['permissions'] as List).map((p) => t(permissionNames[p]!.$1, permissionNames[p]!.$2)).join(' · ')}'),
                              trailing: data!['canManage'] == true
                                  ? const Icon(Icons.edit_outlined)
                                  : null,
                              onTap: data!['canManage'] == true && !busy
                                  ? () => edit(m)
                                  : null));
                    }),
                  if (data!['canManage'] == true) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                        onPressed: busy ? null : () => edit(),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(t('邀请家人 / 临时照护', 'Invite a caregiver')))
                  ],
                  const SizedBox(height: 14),
                  Text(t('临时照护与自定义权限属于高级权益。最后一位管理员需先移交管理权，才能退出。',
                      'Temporary access and custom permissions are advanced benefits. Transfer administration before the last admin leaves.')),
                ],
                const SizedBox(height: 24),
                TextButton(
                    onPressed: busy ? null : leave,
                    child: Text(t('退出当前家庭', 'Leave this household'))),
              ]))));
}

class _RoleEditor extends StatefulWidget {
  const _RoleEditor({required this.home, required this.advanced, this.member});
  final CareHomeState home;
  final bool advanced;
  final Map<String, dynamic>? member;
  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  late String role = widget.member?['role'] as String? ?? 'MEMBER';
  late Set<String> permissions = Set<String>.from(
      widget.member?['permissions'] as List? ?? permissionNames.keys.toList());
  late DateTime? expires =
      DateTime.tryParse(widget.member?['expiresAt'] as String? ?? '')
          ?.toLocal();
  bool saving = false;
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  Future<void> date() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: expires != null && expires!.isAfter(now)
            ? expires!
            : now.add(const Duration(days: 7)),
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 5));
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(expires ?? now));
    if (time != null && mounted) {
      setState(() => expires = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute));
    }
  }

  Future<void> save() async {
    if (role == 'TEMP' && expires == null ||
        expires != null && !expires!.isAfter(DateTime.now())) {
      setState(() => error = t('请选择将来的到期时间', 'Choose a future expiry'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.home.widget.api.request(
          widget.member == null ? 'POST' : 'PATCH',
          widget.member == null
              ? '/invites'
              : '/family/members/${widget.member!['id']}',
          {
            'role': role,
            'permissions': role == 'ADMIN'
                ? permissionNames.keys.toList()
                : permissions.toList(),
            'expiresAt': expires?.toUtc().toIso8601String()
          });
      if (!mounted) return;
      if (widget.member == null) {
        await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
                    title: Text(t('照护邀请', 'Care invitation')),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(t('邀请码 24 小时有效，仅可使用一次。',
                          'Valid for 24 hours and one use.')),
                      const SizedBox(height: 16),
                      SelectableText(result['code'] as String)
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text(t('关闭', 'Close'))),
                      FilledButton(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: result['code'] as String));
                            if (c.mounted) Navigator.pop(c);
                          },
                          child: Text(t('复制', 'Copy')))
                    ]));
      }
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
          title: t(
              widget.member == null ? '邀请一起照护' : '照护权限',
              widget.member == null
                  ? 'Invite a caregiver'
                  : 'Care permissions'),
          subtitle:
              t('按需要分工，让每一份照护都有边界。', 'Give each person the access they need.'),
          saveLabel: t(widget.member == null ? '生成邀请码' : '保存权限',
              widget.member == null ? 'Create invitation' : 'Save permissions'),
          cancelLabel: t('取消', 'Cancel'),
          saving: saving,
          error: error,
          onSave: save,
          children: [
            DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: role,
                decoration: InputDecoration(labelText: t('角色', 'Role')),
                items: roleNames.entries
                    .where((e) =>
                        (widget.member != null || e.key != 'ADMIN') &&
                        (widget.advanced || e.key != 'TEMP' || role == 'TEMP'))
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(t(e.value.$1, e.value.$2))))
                    .toList(),
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                          role = v!;
                          permissions = Set.from(
                              role == 'TEMP' ? ['CARE'] : permissionNames.keys);
                          expires = role == 'TEMP'
                              ? DateTime.now().add(const Duration(days: 7))
                              : null;
                        })),
            if (role != 'ADMIN') ...[
              const SizedBox(height: 16),
              for (final entry in permissionNames.entries)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t(entry.value.$1, entry.value.$2)),
                    value: permissions.contains(entry.key),
                    onChanged: saving || !widget.advanced
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                permissions.add(entry.key);
                              } else {
                                permissions.remove(entry.key);
                              }
                            })),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('设置到期时间', 'Set access expiry')),
                  value: expires != null,
                  onChanged: saving || !widget.advanced || role == 'TEMP'
                      ? null
                      : (v) => setState(() => expires = v
                          ? DateTime.now().add(const Duration(days: 7))
                          : null)),
              if (expires != null)
                OutlinedButton.icon(
                    onPressed: saving ? null : date,
                    icon: const Icon(Icons.schedule),
                    label: Text(expires!.toString().substring(0, 16))),
            ],
          ]);
}

class FamilyWeeklyPage extends StatefulWidget {
  const FamilyWeeklyPage({super.key, required this.home});
  final CareHomeState home;
  @override
  State<FamilyWeeklyPage> createState() => _FamilyWeeklyPageState();
}

class _FamilyWeeklyPageState extends State<FamilyWeeklyPage> {
  DateTime start =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  Map<String, dynamic>? data;
  String? error;
  bool busy = false, trends = false;
  String t(String z, String e) => widget.home.t(z, e);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
      data = null;
    });
    try {
      final zone = await widget.home.reminders.deviceZone();
      final r = await widget.home.widget.api.request('GET',
          '/family/weekly?start=${healthDay(start)}&zoneId=${Uri.encodeQueryComponent(zone)}&trends=$trends');
      if (mounted) setState(() => data = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget stat(String value, String label) => Expanded(
          child: Column(children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(label)
      ]));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('家庭周报', 'Household weekly report'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Row(children: [
                  Expanded(
                      child: Text(t('这一周，一起照顾。', 'This week, together.'),
                          style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(
                      tooltip: t('刷新', 'Refresh'),
                      onPressed: busy ? null : load,
                      icon: const Icon(Icons.refresh))
                ]),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: busy || data?['advanced'] != true
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                                context: context,
                                initialDate: start,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now());
                            if (picked != null && mounted) {
                              setState(() => start = picked.subtract(
                                  Duration(days: picked.weekday - 1)));
                              await load();
                            }
                          },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                        '${healthDay(start)} – ${healthDay(start.add(const Duration(days: 6)))}')),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.all(12), child: Text(error!)),
                if (data != null) ...[
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: const Color(0xffffefcc),
                          borderRadius: BorderRadius.circular(26)),
                      child: Column(children: [
                        Text(
                            data!['completionRate'] == null
                                ? t('暂无到期安排', 'No tasks due')
                                : '${(data!['completionRate'] as num).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.headlineLarge),
                        Text(t('到期安排完成率', 'Completion rate for due tasks')),
                        const SizedBox(height: 20),
                        Row(children: [
                          stat('${data!['due']}', t('已到期', 'Due')),
                          stat('${data!['completed']}', t('已完成', 'Done')),
                          stat('${data!['missed']}', t('遗漏', 'Missed'))
                        ])
                      ])),
                  const SizedBox(height: 24),
                  Text(t('多宠照护', 'Care by pet'),
                      style: Theme.of(context).textTheme.titleLarge),
                  for (final pet in data!['pets'] as List)
                    Card(
                        color: const Color(0xffe5eff8),
                        child: ListTile(
                            leading: const Icon(Icons.pets),
                            title: Text(pet['name'] as String),
                            subtitle: Text(t(
                                '${pet['completed']} / ${pet['due']} 项完成 · ${pet['missed']} 项遗漏',
                                '${pet['completed']} / ${pet['due']} complete · ${pet['missed']} missed')))),
                  const SizedBox(height: 20),
                  Text(t('成员分工', 'Family contributions'),
                      style: Theme.of(context).textTheme.titleLarge),
                  for (final member in data!['members'] as List)
                    ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(member['name'] as String),
                        subtitle: Text(t(
                            '分配 ${member['assigned']} 项 · 实际完成 ${member['completed']} 项',
                            'Assigned ${member['assigned']} · Completed ${member['completed']}'))),
                  Text(t('${data!['unassigned']} 项尚未指定照护人，可在安排详情中分配。',
                      '${data!['unassigned']} tasks have no assignee. Assign them from plan details.')),
                  const SizedBox(height: 20),
                  Text(t('需要留意的遗漏', 'Missed care to review'),
                      style: Theme.of(context).textTheme.titleLarge),
                  if ((data!['missedTasks'] as List).isEmpty)
                    Text(t('本周没有遗漏记录。', 'No missed tasks for this week.')),
                  for (final task in data!['missedTasks'] as List)
                    ListTile(
                        leading: const Icon(Icons.schedule,
                            color: Color(0xffbd7652)),
                        title: Text('${task['petName']} · ${task['title']}'),
                        subtitle: Text(DateTime.parse(task['dueAt'] as String)
                            .toLocal()
                            .toString()
                            .substring(0, 16))),
                  if ((data!['missed'] as num) > 50)
                    Text(t('仅列出最早的 50 项遗漏。',
                        'Showing the earliest 50 missed tasks.')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('近 8 周与多宠趋势 · 高级权益',
                          '8-week multi-pet trends · Advanced')),
                      value: trends,
                      onChanged: busy || data!['advanced'] != true
                          ? null
                          : (v) {
                              setState(() => trends = v);
                              load();
                            }),
                  for (final period in data!['trends'] as List)
                    Card(
                        color: const Color(0xffeaf0e2),
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${period['start']} · ${period['completed']}/${period['due']}'),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                      value: period['due'] == 0
                                          ? 0
                                          : (period['completed'] as num) /
                                              (period['due'] as num)),
                                  const SizedBox(height: 10),
                                  for (final pet in period['pets'] as List)
                                    Text(
                                        '${pet['name']}: ${pet['completed']}/${pet['due']}')
                                ]))),
                  const SizedBox(height: 20),
                  Text(
                      t('仅统计本周截至现在或历史周末已到期、未取消的安排。完成状态取统计截止时的最后操作；分工取当前负责人。已删除记录不参与统计。',
                          'Counts retained, non-cancelled tasks due by now or the historical week end. Completion uses the last action at that cutoff; assignments reflect current assignees.'),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff8d7d70))),
                ]
              ]))));
}
