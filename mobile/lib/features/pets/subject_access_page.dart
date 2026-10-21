import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/theme/app_spacing.dart';

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
                    title: Text(active
                        ? t('撤回资料共享授权？', 'Revoke authorization?')
                        : t('重新确认资料授权', 'Confirm authorization')),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(active
                          ? t('会移除所有已授权成员，并停止此对象的照护操作和提醒。已有记录保留供创建者查看。',
                              'All member access is removed. Care actions and reminders stop. Existing records remain available to the creator.')
                          : t('请确认已获本人同意或有权代表。重新启用后需重新逐人授权。',
                              'Confirm consent or authority to represent this person. Sharing must be granted again.')),
                      if (!active) ...[
                        DropdownButton<String>(
                            value: basis,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                  value: 'SELF', child: Text(t('本人', 'Self'))),
                              DropdownMenuItem(
                                  value: 'REPRESENTATIVE',
                                  child: Text(t('已获同意或有权代表',
                                      'Authorized representative')))
                            ],
                            onChanged: (v) => change(() => basis = v!)),
                        CheckboxListTile(
                            value: confirmed,
                            onChanged: (v) => change(() => confirmed = v!),
                            title: Text(t('我确认有权保存这些资料',
                                'I confirm authorization to store this information'))),
                      ],
                    ])),
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

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('资料授权与共享', 'Authorization & sharing'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: AppSpacing.pageInsets, children: [
                Text(t('此家人档案默认仅创建者可见。家庭角色不会自动获得访问权；查看和照护还受成员模块权限约束。',
                    'This profile is private by default. Household roles do not grant access automatically. Module permissions still apply.')),
                Text(t('撤销共享会在对方下次联网同步时清除本应用缓存和提醒，无法收回已导出的文件或截图。',
                    'Revocation clears app caches and reminders when the other device next syncs. Exported files and screenshots cannot be recalled.')),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Text(error!),
                TextButton(
                    onPressed: busy ? null : load,
                    child: Text(t('重新加载', 'Reload'))),
                if (data != null) ...[
                  ListTile(
                      title: Text(data!['consentActive'] == true
                          ? t('资料授权有效', 'Authorization active')
                          : t('资料授权已撤回', 'Authorization revoked')),
                      trailing: TextButton(
                          onPressed: busy ? null : consent,
                          child: Text(data!['consentActive'] == true
                              ? t('撤回授权', 'Revoke')
                              : t('重新授权', 'Authorize')))),
                  Text(t('查看：可查看档案和记录。照护：可填写照护与健康记录。仅创建者能管理共享和编辑档案。',
                      'View: read profiles and records. Care: update care and health records. Only the creator manages sharing and edits the profile.')),
                  for (final raw in data!['members'] as List)
                    Builder(builder: (_) {
                      final m = raw as Map;
                      return ListTile(
                          title: Text(m['name'] as String),
                          subtitle:
                              Text(t('该对象的访问权限', 'Access to this profile')),
                          trailing: DropdownButton<String>(
                              value: m['accessLevel'] as String,
                              onChanged: busy || data!['consentActive'] != true
                                  ? null
                                  : (v) => grant(m['id'] as String, v!),
                              items: [
                                DropdownMenuItem(
                                    value: 'NONE',
                                    child: Text(t('不共享', 'No access'))),
                                DropdownMenuItem(
                                    value: 'READ',
                                    child: Text(t('查看', 'View'))),
                                DropdownMenuItem(
                                    value: 'CARE', child: Text(t('照护', 'Care')))
                              ]));
                    }),
                ],
              ]))));
}
