import 'dart:convert';
import 'email_action_page.dart';
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
      if (e.status == 401) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        error = e.status == 403
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
    if (!form.currentState!.validate()) return;
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
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (identity?['email'] != null)
            ListTile(
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
                                builder: (_) =>
                                    EmailActionPage(api: widget.api)));
                        if (mounted) await refresh();
                      }),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (identity?['hasPassword'] == false)
            Text(t('此账号使用 Apple 登录，无需本地密码。',
                'This account uses Apple sign-in without a local password.')),
          if (identity?['hasPassword'] != false) ...[
            Text(t('修改密码', 'Change password'),
                style: Theme.of(context).textTheme.titleLarge),
            Form(
                key: form,
                child: Column(children: [
                  TextFormField(
                      controller: oldPassword,
                      obscureText: true,
                      enabled: !busy,
                      decoration: InputDecoration(
                          labelText: t('当前密码', 'Current password')),
                      validator: (s) => s == null || s.isEmpty
                          ? t('请输入当前密码', 'Enter your current password')
                          : null),
                  TextFormField(
                      controller: newPassword,
                      obscureText: true,
                      enabled: !busy,
                      decoration: InputDecoration(
                          labelText: t('新密码（至少 10 位）',
                              'New password (at least 10 characters)')),
                      validator: (s) => s == null ||
                              s.length < 10 ||
                              utf8.encode(s).length > 72
                          ? t('密码须至少 10 位，最多 72 字节',
                              'Use at least 10 characters, at most 72 bytes')
                          : s == oldPassword.text
                              ? t('新密码不能与当前密码相同', 'Choose a different password')
                              : null),
                  TextFormField(
                      controller: confirmation,
                      obscureText: true,
                      enabled: !busy,
                      decoration: InputDecoration(
                          labelText: t('确认新密码', 'Confirm new password')),
                      validator: (s) => s != newPassword.text
                          ? t('两次密码不一致', 'Passwords do not match')
                          : null),
                  const SizedBox(height: 12),
                  Text(t('修改后保留本次登录，其他会话将退出。',
                      'This session stays signed in. All other sessions will be signed out.')),
                  FilledButton(
                      onPressed: busy ? null : changePassword,
                      child: Text(t('修改密码', 'Change password'))),
                ])),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: Text(t('登录会话', 'Sign-in sessions'),
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh),
                tooltip: t('刷新', 'Refresh'))
          ]),
          Text(t('同一设备多次登录可能产生多个会话；设备名称由客户端提供。',
              'A device may have multiple sessions. Device names are reported by the app.')),
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
                                : () => revoke(session['id'] as String)))),
          OutlinedButton(
              onPressed: busy || !sessions.any((s) => s['current'] != true)
                  ? null
                  : () => revoke(),
              child: Text(t('退出其他所有会话', 'Sign out all other sessions'))),
        ]),
      );
}
