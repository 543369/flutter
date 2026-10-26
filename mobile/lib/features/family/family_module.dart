import '../../core/widgets/membership_badge.dart';
import 'member_avatar.dart';
import '../../core/theme/app_spacing.dart';
import 'household_management_pages.dart';
import 'personal_profile_page.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../auth/account_security_page.dart';
import '../benefits/benefits_page.dart';
import '../care/care_view.dart';
import '../care/care_pages.dart';
import 'package:flutter/services.dart';

extension FamilyModule on CareHomeState {
  Future<void> editName() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PersonalProfilePage(home: this)));
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
                    const SizedBox(height: AppSpacing.content),
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
        const SizedBox(height: AppSpacing.tight),
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
                      padding: AppSpacing.cardInsets,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 27),
                            const SizedBox(height: AppSpacing.content),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: AppSpacing.inline),
                            Text(subtitle,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: AppSpacing.item),
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
    final orderedMembers = [
      ...memberProfiles.where((member) => member['isMe'] == true),
      ...memberProfiles.where((member) => member['isMe'] != true),
    ];
    final memories = pets.fold<int>(
        0, (sum, pet) => sum + (pet['memoryCount'] as int? ?? 0));
    return [
      Container(
        padding: AppSpacing.cardInsets,
        decoration: BoxDecoration(
            color: const Color(0xffe4eef6),
            borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('我们的小家', 'Our home'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.inline),
          Text(t(
              '${data?['members'] ?? 1} 位家人 · ${pets.length} 位小伙伴 · $memories 篇回忆',
              '${data?['members'] ?? 1} people · ${pets.length} pets · $memories memories')),
        ]),
      ),
      const SizedBox(height: AppSpacing.section),
      Text(
          t('一起陪伴的人 · ${orderedMembers.length}',
              'The people who care · ${orderedMembers.length}'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.item),
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.item) / 2;
        return Wrap(
          spacing: AppSpacing.item,
          runSpacing: AppSpacing.item,
          children: orderedMembers.take(4).map((member) {
            final isMe = member['isMe'] == true;
            return SizedBox(
              width: width,
              child: Material(
                color: const Color(0xfffff0db),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isMe && !busy ? editName : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.item),
                    child: Row(children: [
                      MemberAvatar(data: member['avatarData'] as String?),
                      const SizedBox(width: AppSpacing.inline),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              isMe
                                  ? t('我 · 查看个人资料', 'Me · personal profile')
                                  : t('家人', 'Family'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      )),
                    ]),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }),
      if (orderedMembers.length > 4)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => HouseholdMembersPage(home: this))),
            label: Text(t('查看全部 ${orderedMembers.length} 位家人',
                'View all ${orderedMembers.length} people')),
            icon: const Icon(Icons.chevron_right_rounded),
            iconAlignment: IconAlignment.end,
          ),
        ),
      const SizedBox(height: AppSpacing.content),
      IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        familyAction(
            t('邀请家人', 'Invite family'),
            t('把照护分享给在意的人', 'Share the care'),
            Icons.person_add_alt_rounded,
            const Color(0xffffe9de),
            busy || !can('ADMIN') ? null : invite),
        const SizedBox(width: AppSpacing.item),
        familyAction(
            t('加入家庭', 'Join a family'),
            t('输入邀请码，成为一份子', 'Enter an invitation code'),
            Icons.home_outlined,
            const Color(0xffeef0e5),
            busy ? null : join),
      ])),
      const SizedBox(height: AppSpacing.section),
      Card(
          color: const Color(0xffffefcc),
          child: ListTile(
            key: const ValueKey('household-benefits'),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.content, vertical: AppSpacing.inline),
            leading: const Icon(Icons.auto_awesome_outlined,
                color: Color(0xffa15e40)),
            title: Wrap(
                spacing: AppSpacing.inline,
                runSpacing: AppSpacing.tight,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(t('家庭权益', 'Household benefits')),
                  MembershipBadge(label: t('会员权益', 'Membership')),
                ]),
            subtitle: Text(t('照片空间 · 回忆录导出 · 年度成长报告',
                'Photo storage · Memory books · Annual reports')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BenefitsPage(home: this))),
          )),
      const SizedBox(height: AppSpacing.item),
      Card(
          color: const Color(0xffe8eee0),
          child: ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: Text(t('家庭周报与多宠统计', 'Weekly report & pet trends')),
              subtitle: Text(t(
                  '完成率、遗漏与成员分工', 'Completion, missed care and contributions')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FamilyWeeklyPage(home: this))))),
      Card(
          color: const Color(0xffffefdf),
          child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(t('家人与照护权限', 'People and permissions')),
              subtitle:
                  Text(t('角色、临时照护与到期时间', 'Roles, temporary care and expiry')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HouseholdMembersPage(home: this))))),
      const SizedBox(height: AppSpacing.item),
      Row(children: [
        Expanded(
            child: Text(t('家里的近况', 'Around the home'),
                style: Theme.of(context).textTheme.titleLarge)),
        const Icon(Icons.favorite_border_rounded,
            size: 20, color: Color(0xffb06c51))
      ]),
      const SizedBox(height: AppSpacing.item),
      Card(
          color: const Color(0xfffaf4ec),
          child: Column(children: [
            if (history.isEmpty)
              Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(t('还没有照护动态。家人完成照护后，会在这里留下记录。',
                      'Family care updates will appear here after a task is completed.'))),
            ...history.take(3).map((event) => ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.content, vertical: AppSpacing.tight),
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
          ])),
      const SizedBox(height: AppSpacing.item),
      Text(t('账号与偏好', 'Account & preferences'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.item),
      Card(
          color: const Color(0xfff5f1ec),
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(t('个人资料', 'Personal profile')),
                subtitle: Text(
                    t('昵称、生日、手机号与账号', 'Name, birthday, phone and account')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : editName),
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
                key: const PageStorageKey('family-data-privacy'),
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(t('数据与隐私', 'Data & privacy')),
                childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.content,
                    0, AppSpacing.content, AppSpacing.content),
                children: [
                  Text(t(
                      '宠物资料按家庭模块权限共享。家人档案默认私有，由创建者逐人授权。资料保存在服务端；加入其他家庭要求当前家庭只有你且没有照护对象。',
                      'Pet records follow household permissions. Human profiles are private until individually shared. Joining another home requires a solo household with no care profiles.')),
                  const SizedBox(height: AppSpacing.item),
                  TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(t('删除我的账号', 'Delete my account')),
                      onPressed: busy
                          ? null
                          : () async {
                              if (await confirm(
                                  t('永久删除？', 'Delete permanently?'),
                                  t('将删除当前身份及你创建的家人照护档案。若你是最后一位成员，家庭全部资料也会删除；否则宠物共享记录保留给家人。',
                                      'Your identity and the human profiles you created will be deleted. If you are the last member, all household data is deleted; otherwise shared pet records remain.'))) {
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
      const SizedBox(height: AppSpacing.item),
      Center(
          child: Text(t('有你们在，小日子就很温暖。', 'Home is warmer with you in it.'),
              style: const TextStyle(fontSize: 12, color: Color(0xff9a887b)))),
    ];
  }
}
