import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/network/care_api.dart';

class EmailActionPage extends StatefulWidget {
  const EmailActionPage({super.key, required this.api, this.recovery = false});
  final CareApi api;
  final bool recovery;
  @override
  State<EmailActionPage> createState() => _EmailActionPageState();
}

class _EmailActionPageState extends State<EmailActionPage> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? message;
  String t(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> act(bool send) async {
    if (busy) return;
    if (!send &&
        (code.text.trim().isEmpty ||
            (widget.recovery &&
                (password.text.length < 10 ||
                    utf8.encode(password.text).length > 72 ||
                    password.text != confirmation.text)))) {
      setState(() => message = t('请检查验证码和密码（至少10位，两次一致）',
          'Check the code and matching passwords (at least 10 characters)'));
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final base = widget.recovery ? '/auth/recovery' : '/auth/email';
      await widget.api.request(
          'POST',
          '$base/${send ? 'request' : 'confirm'}',
          send
              ? (widget.recovery ? {'email': email.text.trim()} : null)
              : {
                  'code': code.text.trim(),
                  if (widget.recovery) 'password': password.text
                });
      if (!mounted) return;
      setState(() => message = send
          ? t('如符合条件，验证码将发送到邮箱；15分钟有效，请查看垃圾邮件。',
              'If eligible, a code will arrive by email. It expires in 15 minutes. Check spam too.')
          : t(
              widget.recovery ? '密码已重置，请返回登录。' : '邮箱验证成功。',
              widget.recovery
                  ? 'Password reset. Return to sign in.'
                  : 'Email verified.'));
      if (!send) {
        password.clear();
        confirmation.clear();
        code.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = e is ApiError && e.status == 503
            ? t('邮件服务尚未配置，请稍后重试。', 'Email service is not configured yet.')
            : t('操作失败：请检查输入、验证码有效期，或稍后重试。',
                'Request failed. Check your input and code expiry, or retry later.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(t(widget.recovery ? '忘记密码' : '验证邮箱',
              widget.recovery ? 'Forgot password' : 'Verify email'))),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (widget.recovery)
          TextField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  InputDecoration(labelText: t('注册邮箱', 'Account email'))),
        Text(t('将邮件中的完整验证码粘贴到下方。',
            'Paste the complete code from the email below.')),
        OutlinedButton(
            onPressed: busy ? null : () => act(true),
            child: Text(t('发送验证码', 'Send code'))),
        TextField(
            controller: code,
            enabled: !busy,
            autocorrect: false,
            decoration: InputDecoration(labelText: t('邮箱验证码', 'Email code'))),
        if (widget.recovery) ...[
          TextField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              decoration: InputDecoration(labelText: t('新密码', 'New password'))),
          TextField(
              controller: confirmation,
              enabled: !busy,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: t('确认新密码', 'Confirm password'))),
        ],
        if (message != null) Text(message!),
        FilledButton(
            onPressed: busy ? null : () => act(false),
            child: Text(t('确认', 'Confirm'))),
      ]));
}
