import 'dart:async';
import '../../core/theme/app_spacing.dart';
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
  bool loading = true, complete = false;
  String? recipient;
  int cooldown = 0;
  Timer? timer;
  DateTime? resendAt;
  @override
  void initState() {
    super.initState();
    if (widget.recovery) {
      loading = false;
    } else {
      loadStatus();
    }
  }

  Future<void> loadStatus() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final status = await widget.api.request('GET', '/auth/email/status');
      if (mounted) {
        setState(() {
          recipient = status['email'] as String?;
          complete = status['verified'] == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => message =
            t('无法读取邮箱，请重试。', 'Could not load your email. Please retry.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void startCooldown() {
    timer?.cancel();
    resendAt = DateTime.now().add(const Duration(seconds: 60));
    setState(() => cooldown = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final seconds =
          (resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 60);
      if (mounted) setState(() => cooldown = seconds);
      if (seconds == 0) timer.cancel();
    });
  }

  String t(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> act(bool send) async {
    if (busy || complete || loading || (send && cooldown > 0)) return;
    String? validation;
    if (send &&
        widget.recovery &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      validation = t('请输入有效的注册邮箱。', 'Enter a valid account email.');
    } else if (!send && code.text.trim().isEmpty) {
      validation =
          t('请输入邮件中的完整验证码。', 'Enter the complete code from your email.');
    } else if (!send &&
        widget.recovery &&
        (password.text.length < 10 || utf8.encode(password.text).length > 72)) {
      validation = t('新密码须至少 10 位，最多 72 字节。',
          'Use at least 10 characters, at most 72 bytes.');
    } else if (!send && widget.recovery && password.text != confirmation.text) {
      validation = t('两次密码不一致。', 'Passwords do not match.');
    }
    if (validation != null) {
      setState(() => message = validation);
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
      if (send) startCooldown();
      if (!send) {
        timer?.cancel();
        setState(() => complete = true);
        password.clear();
        confirmation.clear();
        code.clear();
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiError && e.status == 429) startCooldown();
        setState(() => message = e is ApiError
            ? switch (e.status) {
                400 => send
                    ? t('邮箱格式有误，请检查后重试。',
                        'Check the email address and try again.')
                    : t('验证码无效、已过期或已使用，请重新获取。',
                        'The code is invalid, expired or already used. Request a new one.'),
                401 => t('登录已过期，请返回重新登录。',
                    'Your session expired. Please sign in again.'),
                429 => t('操作太频繁，请等待一分钟再试。',
                    'Too many attempts. Please wait a minute.'),
                503 => t('邮件服务暂不可用，请稍后重试。',
                    'Email service is temporarily unavailable. Try again later.'),
                _ =>
                  t('操作失败，请稍后重试。', 'Request failed. Please try again later.'),
              }
            : t('连接失败，请检查网络后重试。',
                'Connection failed. Check your network and retry.'));
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : complete
              ? Center(
                  child: Padding(
                      padding: AppSpacing.pageInsets,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 64, color: Color(0xff6b8060)),
                        const SizedBox(height: AppSpacing.content),
                        Text(
                            t(
                                widget.recovery ? '密码已重置，请返回登录。' : '邮箱验证成功。',
                                widget.recovery
                                    ? 'Password reset. Return to sign in.'
                                    : 'Email verified.'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (recipient != null)
                          Padding(
                              padding: AppSpacing.cardInsets,
                              child: Text(recipient!)),
                        const SizedBox(height: AppSpacing.section),
                        FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(t(
                                widget.recovery ? '返回登录' : '完成',
                                widget.recovery
                                    ? 'Return to sign in'
                                    : 'Done'))),
                      ])))
              : !widget.recovery && recipient == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(message ??
                          t('此账号尚未绑定邮箱。',
                              'No email is linked to this account.')),
                      TextButton(
                          onPressed: loadStatus, child: Text(t('重试', 'Retry'))),
                    ]))
                  : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(24,
                                constraints.maxHeight > 650 ? 48 : 24, 24, 32),
                            child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xffffe8c9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18)),
                                                child: Icon(
                                                    widget.recovery
                                                        ? Icons
                                                            .lock_reset_rounded
                                                        : Icons
                                                            .mark_email_read_outlined,
                                                    size: 28,
                                                    color: const Color(
                                                        0xff80523f)))),
                                        const SizedBox(
                                            height: AppSpacing.section),
                                        Text(
                                            t(
                                                widget.recovery
                                                    ? '找回你的账号'
                                                    : '让陪伴多一份安心',
                                                widget.recovery
                                                    ? 'Welcome back'
                                                    : 'A little more peace of mind'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        const SizedBox(
                                            height: AppSpacing.inline),
                                        Text(
                                            t(
                                                widget.recovery
                                                    ? '通过注册邮箱接收验证码，为账号设置新密码。'
                                                    : '先发送验证码，再将邮件中的完整验证码粘贴到下方，完成邮箱验证。',
                                                widget.recovery
                                                    ? 'Get a code at your account email to set a new password.'
                                                    : 'Send a code to your email, then paste it below to verify your address.'),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.6,
                                                color: Color(0xff8b7466))),
                                        const SizedBox(
                                            height: AppSpacing.section),
                                        Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                                color: const Color(0xfff8f1e9),
                                                borderRadius:
                                                    BorderRadius.circular(24)),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  if (widget.recovery) ...[
                                                    TextField(
                                                        controller: email,
                                                        enabled: !busy,
                                                        keyboardType:
                                                            TextInputType
                                                                .emailAddress,
                                                        decoration: InputDecoration(
                                                            labelText: t('注册邮箱',
                                                                'Account email'),
                                                            filled: true,
                                                            fillColor:
                                                                const Color(
                                                                    0xfffffcf8))),
                                                    const SizedBox(
                                                        height:
                                                            AppSpacing.item),
                                                  ],
                                                  if (!widget.recovery) ...[
                                                    Text(t('接收邮箱', 'Send to'),
                                                        style: const TextStyle(
                                                            fontSize: 12)),
                                                    const SizedBox(
                                                        height:
                                                            AppSpacing.tight),
                                                    Text(recipient!,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    const SizedBox(
                                                        height:
                                                            AppSpacing.inline),
                                                  ],
                                                  Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: TextButton.icon(
                                                          onPressed: busy ||
                                                                  cooldown > 0
                                                              ? null
                                                              : () => act(true),
                                                          icon: const Icon(
                                                              Icons
                                                                  .send_outlined,
                                                              size: 17),
                                                          label: Text(cooldown >
                                                                  0
                                                              ? t('$cooldown 秒后重发',
                                                                  'Resend in ${cooldown}s')
                                                              : t('发送验证码',
                                                                  'Send code')))),
                                                  const SizedBox(
                                                      height:
                                                          AppSpacing.inline),
                                                  TextField(
                                                      controller: code,
                                                      enabled: !busy,
                                                      autocorrect: false,
                                                      autofillHints: const [
                                                        AutofillHints
                                                            .oneTimeCode
                                                      ],
                                                      decoration: InputDecoration(
                                                          labelText: t('邮箱验证码',
                                                              'Email code'),
                                                          filled: true,
                                                          fillColor:
                                                              const Color(
                                                                  0xfffffcf8))),
                                                  if (widget.recovery) ...[
                                                    const SizedBox(
                                                        height:
                                                            AppSpacing.content),
                                                    TextField(
                                                        controller: password,
                                                        enabled: !busy,
                                                        obscureText: true,
                                                        decoration: InputDecoration(
                                                            labelText: t('新密码',
                                                                'New password'),
                                                            filled: true,
                                                            fillColor:
                                                                const Color(
                                                                    0xfffffcf8))),
                                                    const SizedBox(
                                                        height:
                                                            AppSpacing.content),
                                                    TextField(
                                                        controller:
                                                            confirmation,
                                                        enabled: !busy,
                                                        obscureText: true,
                                                        decoration: InputDecoration(
                                                            labelText: t(
                                                                '确认新密码',
                                                                'Confirm password'),
                                                            filled: true,
                                                            fillColor:
                                                                const Color(
                                                                    0xfffffcf8))),
                                                  ],
                                                  if (message != null) ...[
                                                    const SizedBox(
                                                        height:
                                                            AppSpacing.content),
                                                    Semantics(
                                                        liveRegion: true,
                                                        child: Text(message!,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    height:
                                                                        1.5))),
                                                  ],
                                                  const SizedBox(
                                                      height:
                                                          AppSpacing.section),
                                                  FilledButton(
                                                      style: FilledButton
                                                          .styleFrom(
                                                              minimumSize:
                                                                  const Size
                                                                      .fromHeight(
                                                                      48)),
                                                      onPressed:
                                                          busy
                                                              ? null
                                                              : () =>
                                                                  act(false),
                                                      child: busy
                                                          ? const SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2))
                                                          : Text(t(
                                                              widget.recovery
                                                                  ? '重置密码'
                                                                  : '验证邮箱',
                                                              widget.recovery
                                                                  ? 'Reset password'
                                                                  : 'Verify email'))),
                                                ])),
                                        const SizedBox(
                                            height: AppSpacing.content),
                                        Text(
                                            t('验证码 15 分钟内有效，未收到时也请检查垃圾邮件。',
                                                'Codes expire in 15 minutes. Check your spam folder if needed.'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                                color: Color(0xff8b7466))),
                                      ])),
                            ),
                          )));
}
