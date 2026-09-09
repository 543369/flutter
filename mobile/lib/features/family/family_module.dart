import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../auth/account_security_page.dart';
import 'package:flutter/services.dart';

extension FamilyModule on CareHomeState {
  Future<void> editName() async {
    final controller =
        TextEditingController(text: data?['me'] as String? ?? '');
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(t('我的照护称呼', 'My caregiver name')),
              content: TextField(
                  controller: controller,
                  maxLength: 40,
                  decoration: InputDecoration(
                      labelText: t('家人会在记录中看到这个名字',
                          'Shown to your household in care history'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('取消', 'Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t('保存', 'Save')))
              ],
            ));
    if (saved == true && controller.text.trim().isNotEmpty) {
      await perform(() async {
        await widget.api
            .request('PATCH', '/profile', {'name': controller.text.trim()});
      });
    }
  }

  Future<void> invite() async {
    await perform(() async {
      final result = await widget.api.request('POST', '/invites');
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(t('邀请家人', 'Invite family')),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('24 小时内有效，仅可使用一次。持有人可查看和管理家庭全部宠物与照护事项。',
                          'Valid for 24 hours and one use. The recipient can view and manage all household pets and care tasks.')),
                      const SizedBox(height: 16),
                      SelectableText(result['code'] as String),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('关闭', 'Close'))),
                  FilledButton(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: result['code'] as String));
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(t('复制邀请码', 'Copy invitation')))
                ],
              ));
    });
  }

  Future<void> join() async {
    final code = TextEditingController();
    final valid = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(t('加入家庭', 'Join a household')),
              content: TextField(
                  controller: code,
                  maxLength: 100,
                  decoration:
                      InputDecoration(labelText: t('邀请码', 'Invitation code'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('取消', 'Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t('加入', 'Join')))
              ],
            ));
    final value = code.text.trim();
    if (valid == true && value.isNotEmpty) {
      await perform(() async {
        await widget.api.request('POST', '/join', {'code': value});
      });
    }
  }

  List<Widget> familyView() => [
        if (data?['registered'] == true)
          ListTile(
              leading: const Icon(Icons.security),
              title: Text(t('账号安全', 'Account security')),
              subtitle: Text(t('修改密码、管理登录会话', 'Password and sign-in sessions')),
              onTap: busy
                  ? null
                  : () async {
                      await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AccountSecurityPage(
                                  api: widget.api, translate: t)));
                      if (mounted) await perform(() async {});
                    }),
        if (data?['registered'] == true)
          OutlinedButton.icon(
              onPressed: busy ? null : logout,
              icon: const Icon(Icons.logout),
              label: Text(t('退出登录', 'Sign out')))
        else
          Card(
              child: ListTile(
                  title: Text(t('绑定账号，换机也能登录',
                      'Create an account to sign in on another device')),
                  subtitle: Text(t('保留当前家庭、宠物和照护记录。',
                      'Keep your current household, pets and care history.')),
                  onTap: busy ? null : bindAccount)),
        Text(t('照护是一家人的事', 'Better, together'),
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(data?['me'] as String? ?? ''),
            subtitle: Text(t('我的照护称呼', 'My caregiver name')),
            trailing: IconButton(
                tooltip: t('修改称呼', 'Edit name'),
                onPressed: busy ? null : editName,
                icon: const Icon(Icons.edit_outlined))),
        Text(t('家庭共有 ${data?['members']} 位成员',
            "${data?['members']} household members")),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: busy ? null : invite,
            icon: const Icon(Icons.person_add_alt),
            label: Text(t('生成家庭邀请码', 'Create an invitation'))),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: busy ? null : join,
            child: Text(t('使用邀请码加入家庭', 'Join with an invitation'))),
        const SizedBox(height: 24),
        Text(t('加入条件：当前家庭仅有你，且未添加宠物。邀请加入的人可以管理全部宠物和事项。',
            'To join, your current household must have no pets and only you. Invited members can manage all pets and tasks.')),
        const Divider(height: 40),
        Text(t('数据与隐私', 'Data & privacy'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(t('服务端保存设备身份、家庭关联、宠物名字与种类、照护事项及时间。当前未接入广告、分析或 AI 服务。',
            'The server stores device identities, household membership, pet names and species, and care tasks with their times. No ads, analytics or AI services are connected.')),
        const SizedBox(height: 12),
        Text(t('这是一款日常照护记录工具，不提供诊断或治疗建议。',
            'This app records everyday care and does not provide diagnosis or treatment advice.')),
        const SizedBox(height: 24),
        TextButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: Text(t('删除我的账号', 'Delete my account')),
            onPressed: busy
                ? null
                : () async {
                    if (await confirm(
                        t('永久删除？', 'Delete permanently?'),
                        t('将删除当前身份并退出家庭。如果你是最后一位成员，将同时删除全部宠物与照护数据；否则共享记录保留给其他成员。',
                            'Your identity and membership will be deleted. If you are the last member, all household pets and tasks will be deleted; otherwise shared records remain for other members.'))) {
                      await perform(widget.api.deleteAccount);
                    }
                  }),
      ];
}
