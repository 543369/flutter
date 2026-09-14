import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../auth/account_security_page.dart';
import '../pets/pet_cover.dart';
import '../care/care_view.dart';
import '../care/care_pages.dart';
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
    Map<String, dynamic>? invitation;
    await perform(() async {
      invitation = Map<String, dynamic>.from(
          await widget.api.request('POST', '/invites') as Map);
    });
    if (!mounted || invitation == null) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(t('邀请家人', 'Invite family')),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('24 小时内有效，仅可使用一次。受邀家人可以共同管理宠物、照护与回忆录。',
                        'Valid for 24 hours and one use. Invited family can manage pets, care and memories.')),
                    const SizedBox(height: 18),
                    SelectableText(invitation!['code'] as String),
                  ]),
              actions: [
                Row(children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(t('关闭', 'Close')))),
                  Expanded(
                      child: FilledButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(
                                text: invitation!['code'] as String));
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          child: Text(t('复制邀请码', 'Copy invitation')))),
                ])
              ],
            ));
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

  Widget familyStat(String value, String label) => Expanded(
          child: Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Color(0xff34231e))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]));

  Widget familyAction(String title, String subtitle, IconData icon, Color color,
          VoidCallback? action) =>
      Expanded(
          child: Material(
              color: color,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: action,
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 27),
                            const SizedBox(height: 16),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(subtitle,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 12),
                            const Align(
                                alignment: Alignment.centerRight,
                                child: Icon(Icons.arrow_forward_rounded,
                                    size: 20)),
                          ])))));

  List<Widget> familyView() {
    final memberProfiles = (data?['memberProfiles'] as List? ??
        [
          {'name': data?['me'] ?? '', 'isMe': true}
        ]);
    final memories = pets.fold<int>(
        0, (sum, pet) => sum + (pet['memoryCount'] as int? ?? 0));
    return [
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0xffe4eef6),
              borderRadius: BorderRadius.circular(28)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.favorite_rounded,
                  color: Color(0xffcf6947), size: 19),
              const SizedBox(width: 8),
              Text(t('我们的小家', 'OUR LITTLE HOME'),
                  style: const TextStyle(fontSize: 12, letterSpacing: 1.5))
            ]),
            const SizedBox(height: 16),
            Text(t('一起照顾，\n一起珍藏。', 'Care together.\nKeep the memories.'),
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(t('有人惦记，有人陪伴，就是家的样子。',
                'A little care from everyone makes a home.')),
            if (pets.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pets
                      .take(5)
                      .map((pet) => SizedBox(
                          width: 52,
                          height: 52,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: PetCover(pet: pet))))
                      .toList()),
            ],
            const SizedBox(height: 22),
            Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  familyStat('${data?['members'] ?? 1}', t('位家人', 'Members')),
                  familyStat('${pets.length}', t('位小伙伴', 'Pets')),
                  familyStat('$memories', t('篇回忆', 'Memories'))
                ])),
          ])),
      const SizedBox(height: 26),
      Text(t('一起陪伴的人', 'The people who care'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      Wrap(
          spacing: 10,
          runSpacing: 10,
          children: memberProfiles
              .map((member) => Material(
                  color: const Color(0xfffff0db),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: member['isMe'] == true && !busy ? editName : null,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const CircleAvatar(
                              radius: 21,
                              backgroundColor: Colors.white,
                              child:
                                  Icon(Icons.person_outline_rounded, size: 23)),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(member['name'] as String,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        member['isMe'] == true
                                            ? t('我 · 点击修改称呼', 'Me · edit name')
                                            : t('家人', 'Family'),
                                        style: const TextStyle(fontSize: 11)),
                                  ])),
                          if (member['isMe'] == true) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_outlined, size: 16)
                          ],
                        ])),
                  )))
              .toList()),
      const SizedBox(height: 18),
      IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        familyAction(
            t('邀请家人', 'Invite family'),
            t('把照护分享给在意的人', 'Share the care'),
            Icons.person_add_alt_rounded,
            const Color(0xffffe9de),
            busy ? null : invite),
        const SizedBox(width: 12),
        familyAction(
            t('加入家庭', 'Join a family'),
            t('输入邀请码，成为一份子', 'Enter an invitation code'),
            Icons.home_outlined,
            const Color(0xffeef0e5),
            busy ? null : join),
      ])),
      const SizedBox(height: 26),
      Row(children: [
        Expanded(
            child: Text(t('家里的近况', 'Around the home'),
                style: Theme.of(context).textTheme.titleLarge)),
        const Icon(Icons.favorite_border_rounded,
            size: 20, color: Color(0xffb06c51))
      ]),
      const SizedBox(height: 12),
      Card(
          color: const Color(0xfffaf4ec),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                if (history.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(t('还没有照护动态。家人完成照护后，会在这里留下记录。',
                          'Family care updates will appear here after a task is completed.'))),
                ...history.take(3).map((event) => ListTile(
                    leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xffe9eee1),
                        child: Icon(
                            event['action'] == 'REOPENED'
                                ? Icons.undo_rounded
                                : Icons.check_rounded,
                            size: 20)),
                    title: Text('${event['petName']} · ${event['title']}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${event['actor'] ?? t('家人', 'Family')} · ${dateLabel(DateTime.parse(event['at'] as String).toLocal())}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                    onTap: () => openRecordDetails(event))),
              ]))),
      const SizedBox(height: 20),
      Text(t('账号与偏好', 'Account & preferences'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(
          color: const Color(0xfff5f1ec),
          child: Column(children: [
            if (data?['registered'] == true)
              ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(t('账号安全', 'Account security')),
                  subtitle:
                      Text(t('密码、登录设备与安全设置', 'Password and signed-in devices')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: busy
                      ? null
                      : () async {
                          await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AccountSecurityPage(
                                      api: widget.api, translate: t)));
                          if (mounted) await perform(() async {});
                        })
            else
              ListTile(
                  leading: const Icon(Icons.person_add_outlined),
                  title: Text(t('绑定账号', 'Create an account')),
                  subtitle: Text(t(
                      '换台设备，也能找到这个家', 'Keep your home when changing devices')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: busy ? null : bindAccount),
            ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: Text(t('提醒设置', 'Reminder settings')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: openReminderSettings),
            ExpansionTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(t('数据与隐私', 'Data & privacy')),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(t(
                      '家庭成员可共同管理宠物、照护和回忆录。照片、故事和档案保存在服务端，只对家庭成员开放。加入其他家庭要求当前家庭只有你且没有宠物。',
                      'Household members share pets, care and memories. Photos, stories and profiles are stored on the server and are only available to your household. Joining another home requires a solo household with no pets.')),
                  const SizedBox(height: 14),
                  TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(t('删除我的账号', 'Delete my account')),
                      onPressed: busy
                          ? null
                          : () async {
                              if (await confirm(
                                  t('永久删除？', 'Delete permanently?'),
                                  t('将删除当前身份并退出家庭。若你是最后一位成员，宠物、照护和回忆录也会删除；否则共享记录保留给家人。',
                                      'Your identity will be deleted. If you are the last member, all pets, care and memories will also be deleted; otherwise shared records remain for your family.'))) {
                                await perform(widget.api.deleteAccount);
                              }
                            }),
                ]),
            if (data?['registered'] == true)
              ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(t('退出登录', 'Sign out')),
                  onTap: busy ? null : logout),
          ])),
      const SizedBox(height: 12),
      Center(
          child: Text(t('有你们在，小日子就很温暖。', 'Home is warmer with you in it.'),
              style: const TextStyle(fontSize: 12, color: Color(0xff9a887b)))),
    ];
  }
}
