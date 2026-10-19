import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/care_api.dart';
import '../../core/theme/app_spacing.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage(
      {super.key, required this.api, required this.translate});
  final CareApi api;
  final String Function(String, String) translate;
  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool busy = false, sent = false;
  int cooldown = 0;
  Timer? timer;
  String? error;
  String t(String z, String e) => widget.translate(z, e);
  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit({required bool confirm}) async {
    if (busy) return;
    final address = email.text.trim();
    if ((!confirm &&
            (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address) ||
                password.text.isEmpty)) ||
        (confirm && code.text.trim().isEmpty)) {
      setState(() => error = t(
          confirm ? '请输入新邮箱收到的验证码' : '请填写新邮箱和当前密码',
          confirm
              ? 'Enter the code sent to your new email'
              : 'Enter your new email and current password'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
          'POST',
          '/auth/email/change/${confirm ? 'confirm' : 'request'}',
          confirm
              ? {'code': code.text.trim()}
              : {'email': address, 'password': password.text});
      password.clear();
      if (!mounted) return;
      if (confirm) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        sent = true;
        cooldown = 60;
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => cooldown--);
        if (cooldown <= 0) timer.cancel();
      });
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => error = switch (e.code) {
              'CURRENT_PASSWORD_INVALID' =>
                t('当前密码不正确', 'Current password is incorrect'),
              'EMAIL_IN_USE' => t('此邮箱已用于其他账号，请使用另一个邮箱。',
                  'This email belongs to another account. Choose another email.'),
              'EMAIL_UNCHANGED' =>
                t('请填写不同于当前账号的新邮箱。', 'Enter a different email address.'),
              'EMAIL_VERIFICATION_REQUIRED' =>
                t('请先验证当前邮箱。', 'Verify your current email first.'),
              'EMAIL_CHANGE_INVALID' => t('验证码无效、已过期，或账号信息已变化，请重新发送。',
                  'The code is invalid or expired, or your account changed. Request a new code.'),
              _ => e.status == 503
                  ? t('邮件服务暂不可用，请稍后重试。',
                      'Email service unavailable. Try again later.')
                  : e.status == 429
                      ? t('发送太频繁，请稍后重试。', 'Too many attempts. Try again later.')
                      : e.status == 401
                          ? t('登录已失效，请重新登录。',
                              'Your session expired. Sign in again.')
                          : t('更换失败，请重试。',
                              'Could not change email. Please retry.'),
            });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => error = t('连接失败，请重试。', 'Connection failed. Please retry.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('更换登录邮箱', 'Change sign-in email'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(padding: AppSpacing.pageInsets, children: [
                Text(t('验证当前密码及新邮箱后更换。账号、家庭和宠物资料保留；当前登录保留，其他登录会话将退出，旧邮箱会收到通知。',
                    'Verify your current password and new email. Your account, household and pets stay. Other sessions will be signed out; your previous email will be notified.')),
                const SizedBox(height: 24),
                TextField(
                    controller: email,
                    enabled: !busy && !sent,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration:
                        InputDecoration(labelText: t('新邮箱', 'New email'))),
                const SizedBox(height: 16),
                TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                        labelText: t('当前密码（发送验证码时验证）',
                            'Current password (required to send code)'))),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: busy || cooldown > 0
                        ? null
                        : () => submit(confirm: false),
                    child: Text(cooldown > 0
                        ? t('${cooldown}s 后可重发', 'Resend in ${cooldown}s')
                        : t(sent ? '重新发送验证码' : '发送验证码',
                            sent ? 'Resend code' : 'Send code'))),
                if (sent) ...[
                  Text(t('验证码已发送到 ${email.text.trim()}，请检查收件箱与垃圾邮件。',
                      'Code sent to ${email.text.trim()}. Check your inbox and spam folder.')),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                sent = false;
                                code.clear();
                                error = null;
                              });
                            },
                      child: Text(t('重新填写邮箱', 'Use another email'))),
                  TextField(
                      controller: code,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                          labelText: t('新邮箱验证码', 'New email code'))),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: busy ? null : () => submit(confirm: true),
                      child: Text(t('确认更换邮箱', 'Confirm email change'))),
                ],
                if (busy)
                  const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.item),
                      child: LinearProgressIndicator()),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.item),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ]))));
}
