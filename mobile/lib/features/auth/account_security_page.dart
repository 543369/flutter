import '../../core/theme/app_spacing.dart';
import 'dart:convert';
import 'email_action_page.dart';
import 'change_email_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../core/network/care_api.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage(
      {super.key, required this.api, required this.translate});
  final CareApi api;
  final String Function(String, String) translate;
  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final form = GlobalKey<FormState>();
  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmation = TextEditingController();
  List<dynamic> sessions = [];
  Map<String, dynamic>? identity;
  bool busy = false;
  String? error;
  String t(String zh, String en) => widget.translate(zh, en);
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'APPLE_ALREADY_LINKED' ||
          e.code == 'APPLE_LINK_EXPIRED' ||
          e.code == 'APPLE_IDENTITY_INVALID' ||
          e.code == 'CURRENT_PASSWORD_INVALID') {
        setState(() => error = switch (e.code) {
              'APPLE_ALREADY_LINKED' => t('此 Apple 身份已绑定账号，不能覆盖或合并已有账号。',
                  'This Apple identity is already linked. Existing accounts cannot be overwritten or merged.'),
              'CURRENT_PASSWORD_INVALID' =>
                t('当前密码不正确', 'Current password is incorrect'),
              _ => t('Apple 授权无效或已过期，请重新绑定。',
                  'Apple authorization is invalid or expired. Try linking again.'),
            });
        return;
      }
      if (e.status == 503) {
        setState(() => error = t('Apple 登录尚未配置完成，请稍后再试。',
            'Apple sign-in is not configured yet. Please try later.'));
        return;
      }
      if (e.status == 401) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        if (e.code == 'EMAIL_VERIFICATION_REQUIRED' && identity != null) {
          identity!['verified'] = false;
        }
        error = e.code == 'EMAIL_VERIFICATION_REQUIRED'
            ? t('请先验证邮箱，再修改密码',
                'Verify your email before changing your password')
            : e.status == 403
                ? t('当前密码不正确', 'Current password is incorrect')
                : e.status == 429
                    ? t('操作太频繁，请稍后重试', 'Too many attempts. Try again later.')
                    : t('操作失败，请刷新后重试（${e.status}）',
                        'Request failed. Refresh and retry (${e.status}).');
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = t('连接失败，请重试', 'Connection failed. Please retry.');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> load() async {
    final result = await widget.api.request('GET', '/auth/sessions');
    final status = await widget.api.request('GET', '/auth/email/status');
    if (mounted) {
      setState(() {
        sessions = result as List;
        identity = Map<String, dynamic>.from(status as Map);
      });
    }
  }

  Future<void> refresh() => run(load);
  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t('取消', 'Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t('确认', 'Confirm'))),
              ])) ??
      false;
  Future<void> revoke([String? id]) async {
    if (!await confirm(t('退出所选登录会话？对应设备需要重新登录。',
        'Sign out the selected sessions? They will need to sign in again.'))) {
      return;
    }
    if (!mounted) return;
    await run(() async {
      await widget.api.request(id == null ? 'POST' : 'DELETE',
          id == null ? '/auth/sessions/revoke-others' : '/auth/sessions/$id');
      await load();
    });
  }

  Future<void> changePassword() async {
    if (identity?['verified'] != true || identity?['hasPassword'] != true) {
      return;
    }
    if (!(form.currentState?.validate() ?? false)) return;
    await run(() async {
      await widget.api.request('POST', '/auth/password', {
        'oldPassword': oldPassword.text,
        'newPassword': newPassword.text,
      });
      oldPassword.clear();
      newPassword.clear();
      confirmation.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('密码已修改，其他登录会话已退出',
                'Password changed. Other sessions have been signed out.'))));
      }
      await load();
    });
  }

  Future<void> changeEmail() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            ChangeEmailPage(api: widget.api, translate: widget.translate)));
    if (mounted && changed == true) {
      await refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('登录邮箱已更换，其他会话已退出。',
                'Email changed. Other sessions have been signed out.'))));
      }
    }
  }

  Future<void> linkApple() async {
    final value = await showDialog<String>(
        context: context,
        builder: (_) => _ApplePasswordDialog(translate: widget.translate));
    if (value == null || !mounted) return;
    await run(() async {
      final challenge = await widget.api
          .request('POST', '/auth/apple/link/challenge', {'password': value});
      final identityToken = await const MethodChannel('petcare/apple')
          .invokeMethod<String>('signIn', challenge['nonce']);
      if (identityToken == null) return;
      await widget.api.request('POST', '/auth/apple/link',
          {'identityToken': identityToken, 'nonce': challenge['nonce']});
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('Apple 已绑定，以后可使用 Apple 登录当前账号。',
                'Apple linked. You can now use Apple to sign into this account.'))));
      }
    });
  }

  String date(dynamic value) => value == null
      ? t('未知', 'Unknown')
      : (DateTime.tryParse(value.toString())
              ?.toLocal()
              .toString()
              .split('.')
              .first ??
          t('未知', 'Unknown'));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('账号安全', 'Account security'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(padding: AppSpacing.pageInsets, children: [
                  if (identity?['email'] != null) ...[
                    Card(
                        color: const Color(0xffe8eee0),
                        child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: const Icon(Icons.mark_email_read_outlined),
                            subtitle: Text(identity?['verified'] == true
                                ? t('邮箱已验证', 'Email verified')
                                : t('邮箱尚未验证', 'Email not verified')),
                            title: Text(t('验证邮箱', 'Verify email')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: busy
                                ? null
                                : () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => EmailActionPage(
                                                api: widget.api)));
                                    if (mounted) await refresh();
                                  })),
                    const SizedBox(height: AppSpacing.item),
                  ],
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (identity?['hasPassword'] == false)
                    Text(t('此账号使用 Apple 登录，无需本地密码。',
                        'This account uses Apple sign-in without a local password.')),
                  if (identity?['hasPassword'] == true) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.content),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8f1e9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: const Color(0xffffe8c9),
                                      borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.lock_outline_rounded,
                                      size: 22, color: Color(0xff80523f))),
                              const SizedBox(width: AppSpacing.item),
                              Text(t('修改密码', 'Change password'),
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                            ]),
                            const SizedBox(height: AppSpacing.section),
                            if (identity?['verified'] != true)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.item),
                                child: Text(t('请先完成上方的邮箱验证，再修改密码。',
                                    'Verify your email above before changing your password.')),
                              ),
                            Form(
                                key: form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                          controller: oldPassword,
                                          obscureText: true,
                                          enabled: !busy &&
                                              identity?['verified'] == true,
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                              filled: true,
                                              fillColor:
                                                  const Color(0xfffffcf8),
                                              labelText: t(
                                                  '当前密码', 'Current password')),
                                          validator: (s) => s == null ||
                                                  s.isEmpty
                                              ? t('请输入当前密码',
                                                  'Enter your current password')
                                              : null),
                                      const SizedBox(
                                          height: AppSpacing.content),
                                      TextFormField(
                                          controller: newPassword,
                                          obscureText: true,
                                          enabled: !busy &&
                                              identity?['verified'] == true,
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                              filled: true,
                                              fillColor:
                                                  const Color(0xfffffcf8),
                                              labelText: t('新密码（至少 10 位）',
                                                  'New password (at least 10 characters)')),
                                          validator: (s) => s == null ||
                                                  s.length < 10 ||
                                                  utf8.encode(s).length > 72
                                              ? t('密码须至少 10 位，最多 72 字节',
                                                  'Use at least 10 characters, at most 72 bytes')
                                              : s == oldPassword.text
                                                  ? t('新密码不能与当前密码相同',
                                                      'Choose a different password')
                                                  : null),
                                      const SizedBox(
                                          height: AppSpacing.content),
                                      TextFormField(
                                          controller: confirmation,
                                          obscureText: true,
                                          enabled: !busy &&
                                              identity?['verified'] == true,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                              filled: true,
                                              fillColor:
                                                  const Color(0xfffffcf8),
                                              labelText: t('确认新密码',
                                                  'Confirm new password')),
                                          validator: (s) =>
                                              s != newPassword.text
                                                  ? t('两次密码不一致',
                                                      'Passwords do not match')
                                                  : null),
                                      const SizedBox(height: AppSpacing.item),
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                                Icons.info_outline_rounded,
                                                size: 16,
                                                color: Color(0xff8b7466)),
                                            const SizedBox(
                                                width: AppSpacing.inline),
                                            Expanded(
                                                child: Text(
                                                    t('修改后保留本次登录，其他会话将退出。',
                                                        'This session stays signed in. All other sessions will be signed out.'),
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        height: 1.5,
                                                        color: Color(
                                                            0xff8b7466)))),
                                          ]),
                                      const SizedBox(height: AppSpacing.inline),
                                      FilledButton(
                                          style: FilledButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(48)),
                                          onPressed: busy ||
                                                  identity?['verified'] != true
                                              ? null
                                              : changePassword,
                                          child: Text(
                                              t('修改密码', 'Change password'))),
                                    ])),
                          ]),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  if (identity?['hasPassword'] == true &&
                      identity?['email'] != null)
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: Text(t('更换登录邮箱', 'Change sign-in email')),
                      subtitle: Text(identity!['email'] as String),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy || identity?['verified'] != true
                          ? null
                          : changeEmail,
                    )),
                  if (identity?['appleLinked'] == true ||
                      (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.iOS &&
                          identity?['hasPassword'] == true))
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.apple),
                      title: Text(t('Apple 登录', 'Apple sign-in')),
                      subtitle: Text(identity?['appleLinked'] == true
                          ? t('已绑定当前账号', 'Linked to this account')
                          : t('绑定后可用 Apple 登录同一账号',
                              'Link Apple to sign into this same account')),
                      trailing: identity?['appleLinked'] == true
                          ? const Icon(Icons.check_circle_outline)
                          : const Icon(Icons.chevron_right),
                      onTap: busy ||
                              identity?['appleLinked'] == true ||
                              identity?['verified'] != true
                          ? null
                          : linkApple,
                    )),
                  Row(children: [
                    Expanded(
                        child: Text(t('登录会话', 'Sign-in sessions'),
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        onPressed: busy ? null : refresh,
                        icon: const Icon(Icons.refresh),
                        tooltip: t('刷新', 'Refresh'))
                  ]),
                  Text(
                      t('同一设备多次登录可能产生多个会话；设备名称由客户端提供。',
                          'A device may have multiple sessions. Device names are reported by the app.'),
                      style: const TextStyle(
                          fontSize: 12, height: 1.5, color: Color(0xff8b7466))),
                  const SizedBox(height: AppSpacing.item),
                  for (final session in sessions)
                    Card(
                        child: ListTile(
                            title: Text(
                                '${session['deviceName']} ${session['current'] == true ? t('（当前）', '(current)') : ''}'),
                            subtitle: Text(
                                '${t('登录时间', 'Signed in')}: ${date(session['createdAt'])}\n${t('最近活动', 'Last active')}: ${date(session['lastSeenAt'])}'),
                            trailing: session['current'] == true
                                ? null
                                : IconButton(
                                    tooltip: t('退出此会话', 'Sign out session'),
                                    icon: const Icon(Icons.logout),
                                    onPressed: busy
                                        ? null
                                        : () =>
                                            revoke(session['id'] as String)))),
                  OutlinedButton(
                      onPressed:
                          busy || !sessions.any((s) => s['current'] != true)
                              ? null
                              : () => revoke(),
                      child:
                          Text(t('退出其他所有会话', 'Sign out all other sessions'))),
                ]))),
      );
}

class _ApplePasswordDialog extends StatefulWidget {
  const _ApplePasswordDialog({required this.translate});
  final String Function(String, String) translate;
  @override
  State<_ApplePasswordDialog> createState() => _ApplePasswordDialogState();
}

class _ApplePasswordDialogState extends State<_ApplePasswordDialog> {
  final password = TextEditingController();
  String t(String z, String e) => widget.translate(z, e);
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(t('绑定 Apple 登录', 'Link Apple sign-in')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t('请输入当前爪伴密码，再完成 Apple 授权。绑定后两种方式登录同一账号，家庭资料保留。',
              'Enter your current PetCare password, then authorize Apple. Both methods will sign into this account and keep your household.')),
          TextField(
              controller: password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration:
                  InputDecoration(labelText: t('当前密码', 'Current password'))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('取消', 'Cancel'))),
          FilledButton(
              onPressed: password.text.isEmpty
                  ? null
                  : () => Navigator.pop(context, password.text),
              child: Text(t('继续绑定', 'Continue linking')))
        ],
      );
}
