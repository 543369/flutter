import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_select.dart';

class SubjectAccessPage extends StatefulWidget {
  const SubjectAccessPage(
      {super.key, required this.home, required this.subject});
  final CareHomeState home;
  final Map<String, dynamic> subject;
  @override
  State<SubjectAccessPage> createState() => _SubjectAccessPageState();
}

class _SubjectAccessPageState extends State<SubjectAccessPage> {
  Map<String, dynamic>? data;
  bool busy = false;
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  String get path => '/subjects/${widget.subject['id']}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final r = await widget.home.widget.api.request('GET', '$path/access');
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(r as Map);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> grant(String member, String level) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.home.widget.api
          .request('PUT', '$path/access/$member', {'level': level});
      if (mounted) {
        await load();
        await widget.home.refreshQuietly();
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> consent() async {
    final active = data?['consentActive'] == true;
    String basis = 'SELF';
    bool confirmed = false;
    final result = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, change) => AlertDialog(
                    titleTextStyle: Theme.of(c).textTheme.titleLarge,
                    contentTextStyle: Theme.of(c).textTheme.bodyMedium,
                    title: Text(active
                        ? t('撤回资料共享授权？', 'Revoke authorization?')
                        : t('重新确认资料授权', 'Confirm authorization')),
                    content: SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(active
                                  ? t('会移除所有已授权成员，并停止此对象的照护操作和提醒。已有记录保留供创建者查看。',
                                      'All member access is removed. Care actions and reminders stop. Existing records remain available to the creator.')
                                  : t('请确认已获本人同意或有权代表。重新启用后需重新逐人授权。',
                                      'Confirm consent or authority to represent this person. Sharing must be granted again.')),
                              if (!active) ...[
                                const SizedBox(height: AppSpacing.content),
                                AppSelect<String>(
                                    initialValue: basis,
                                    decoration: InputDecoration(
                                        labelText:
                                            t('资料授权依据', 'Authorization basis')),
                                    items: [
                                      DropdownMenuItem(
                                          value: 'SELF',
                                          child: Text(t('本人', 'Self'))),
                                      DropdownMenuItem(
                                          value: 'REPRESENTATIVE',
                                          child: Text(t('已获同意或有权代表',
                                              'Authorized representative')))
                                    ],
                                    onChanged: (v) => change(() => basis = v!)),
                                const SizedBox(height: AppSpacing.inline),
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: confirmed,
                                    onChanged: (v) =>
                                        change(() => confirmed = v!),
                                    title: Text(t('我确认有权保存这些资料',
                                        'I confirm authorization to store this information'))),
                              ],
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(t('取消', 'Cancel'))),
                      FilledButton(
                          onPressed: active || confirmed
                              ? () => Navigator.pop(c, true)
                              : null,
                          child: Text(t('确认', 'Confirm')))
                    ])));
    if (result != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.home.widget.api.request('POST', '$path/consent',
          {'basis': basis, 'confirmed': confirmed, 'revoke': active});
      if (mounted) {
        await load();
        await widget.home.refreshQuietly();
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget panel({required Widget child, Color? color}) => Container(
      margin: AppSpacing.cardMargin,
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(22)),
      child: child);

  Widget description(String text) => Text(text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5));

  Widget permission(IconData icon, String title, String detail) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: const Color(0xff92745f)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          description(detail),
        ])),
      ]));

  @override
  Widget build(BuildContext context) {
    final active = data?['consentActive'] == true;
    final members = data?['members'] as List? ?? [];
    final shared = members.where((m) => m['accessLevel'] != 'NONE').length;
    return Scaffold(
      appBar: AppBar(title: Text(t('资料授权与共享', 'Authorization & sharing'))),
      body: SafeArea(
          top: false,
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(padding: AppSpacing.pageInsets, children: [
              panel(
                  color: const Color(0xfff2e8dc),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: const Color(0xfffffcf7),
                                  borderRadius: BorderRadius.circular(16)),
                              child:
                                  const Icon(Icons.shield_outlined, size: 28)),
                          const SizedBox(width: AppSpacing.item),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(widget.subject['name'] as String? ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                description(t('家人档案 · 由你管理共享',
                                    'Family profile · You manage access')),
                              ])),
                        ]),
                        const SizedBox(height: AppSpacing.content),
                        description(t('默认仅创建者可见。加入家庭或成为管理员，不会自动获得访问权。',
                            'Private to the creator by default. Joining the household or becoming an admin does not grant access.')),
                        if (data != null) ...[
                          const SizedBox(height: AppSpacing.content),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, constraints) {
                            final status = Row(children: [
                              Icon(
                                  active
                                      ? Icons.verified_user_outlined
                                      : Icons.lock_outline,
                                  size: 18),
                              const SizedBox(width: AppSpacing.inline),
                              Expanded(
                                  child: Text(
                                      active
                                          ? t('资料授权有效', 'Authorization active')
                                          : t('资料授权已撤回',
                                              'Authorization revoked'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                            ]);
                            final action = TextButton(
                                onPressed: busy ? null : consent,
                                child: Text(active
                                    ? t('撤回授权', 'Revoke')
                                    : t('重新授权', 'Authorize')));
                            if (constraints.maxWidth < 280 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    20) {
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    status,
                                    const SizedBox(height: AppSpacing.inline),
                                    action,
                                  ]);
                            }
                            return Row(
                                children: [Expanded(child: status), action]);
                          }),
                        ],
                      ])),
              if (busy)
                const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator()),
              if (error != null)
                panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: busy ? null : load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(t('重新加载', 'Reload'))),
                    ])),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t('成员共享', 'Member access'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (data != null) ...[
                        const SizedBox(height: AppSpacing.tight),
                        Text(t('已共享 $shared 人', 'Shared with $shared'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ])),
                IconButton(
                    onPressed: busy ? null : load,
                    tooltip: t('重新加载', 'Reload'),
                    icon: const Icon(Icons.refresh_rounded, size: 20)),
              ]),
              const SizedBox(height: AppSpacing.item),
              if (data != null && !active)
                Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.content),
                    child: description(t('重新授权后，才能为成员设置访问权限。',
                        'Authorize again to set member access.'))),
              if (data != null && members.isEmpty)
                panel(
                    child: Column(children: [
                  const Icon(Icons.group_add_outlined,
                      size: 30, color: Color(0xff92745f)),
                  const SizedBox(height: 12),
                  Text(t('暂无可授权的家庭成员', 'No household members to share with'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  description(t('先邀请家人加入家庭，再到这里逐人设置权限。',
                      'Invite someone to your household, then choose their access here.')),
                ])),
              for (final raw in members)
                Builder(builder: (_) {
                  final m = raw as Map;
                  final name = m['name'] as String;
                  return panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          CircleAvatar(
                              backgroundColor: const Color(0xffeee2d5),
                              child: Text(
                                  name.isEmpty ? '?' : name.characters.first)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: AppSpacing.tight),
                                description(
                                    t('该对象的访问权限', 'Access to this profile')),
                              ])),
                        ]),
                        const SizedBox(height: 16),
                        AppSelect<String>(
                          key: ValueKey('subject-access-${m['id']}'),
                          initialValue: m['accessLevel'] as String,
                          decoration: InputDecoration(
                              labelText: t('访问权限', 'Access level')),
                          onChanged: busy || !active
                              ? null
                              : (v) => grant(m['id'] as String, v!),
                          items: [
                            DropdownMenuItem(
                                value: 'NONE',
                                child: Text(t('不共享', 'No access'))),
                            DropdownMenuItem(
                                value: 'READ', child: Text(t('查看', 'View'))),
                            DropdownMenuItem(
                                value: 'CARE', child: Text(t('照护', 'Care'))),
                          ],
                        ),
                      ]));
                }),
              panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t('权限说明', 'Access levels'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    permission(
                        Icons.visibility_outlined,
                        t('查看', 'View access'),
                        t('可查看档案和记录。', 'Read the profile and records.')),
                    permission(
                        Icons.favorite_border_rounded,
                        t('照护', 'Care access'),
                        t('可填写照护与健康记录，仍受成员模块权限约束。',
                            'Update care and health records, subject to member module permissions.')),
                    permission(
                        Icons.manage_accounts_outlined,
                        t('创建者', 'Creator'),
                        t('仅创建者能管理共享和编辑档案。',
                            'Only the creator manages sharing and edits the profile.')),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: Color(0xff92745f)),
                        const SizedBox(width: AppSpacing.inline),
                        Expanded(
                            child: description(t(
                                '撤销共享后，对方设备将在下次联网同步时清除本应用缓存与提醒；已导出的文件或截图无法收回。',
                                'Revocation clears app caches and reminders on the next online sync. Exported files and screenshots cannot be recalled.'))),
                      ])),
            ]),
          ))),
    );
  }
}
