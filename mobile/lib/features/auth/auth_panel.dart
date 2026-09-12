import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'email_action_page.dart';
import 'package:flutter/material.dart';
import '../../core/network/care_api.dart';

class AuthPanel extends StatefulWidget {
  const AuthPanel(
      {super.key,
      required this.api,
      required this.onAuthenticated,
      this.binding = false});
  final CareApi api;
  final Future<void> Function() onAuthenticated;
  final bool binding;
  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<AuthPanel> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      confirmation = TextEditingController();
  late bool registering = widget.binding;
  bool busy = false, hidden = true;
  String? error;
  String t(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (registering) {
        await widget.api.register(email.text, password.text, name.text);
      } else {
        await widget.api.login(email.text, password.text);
      }
      if (mounted) await widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is PlatformException
            ? t('无法保存登录凭据，请检查系统钥匙串权限。',
                'Cannot save sign-in credentials. Check system keychain permissions.')
            : e is ApiError
                ? e.status == 401
                    ? t('邮箱或密码不正确，或当前设备登录已失效。',
                        'Incorrect email or password, or the current session has expired.')
                    : e.status == 409
                        ? t('该邮箱已注册，或当前账号已经绑定邮箱。',
                            'Email already registered, or this account already has an email.')
                        : e.status == 429
                            ? t('尝试过于频繁，请一分钟后重试。',
                                'Too many attempts. Try again in a minute.')
                            : e.status == 400
                                ? t('请检查邮箱和密码格式。',
                                    'Please check your email and password.')
                                : t('服务暂不可用，请稍后重试。',
                                    'Service unavailable. Please retry.')
                : t('连接失败，请检查网络和服务地址。',
                    'Connection failed. Check your network and server address.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> apple() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final challenge =
          await widget.api.request('POST', '/auth/apple/challenge');
      final identity = await const MethodChannel('petcare/apple')
          .invokeMethod<String>('signIn', challenge['nonce']);
      final result = await widget.api.request('POST', '/auth/apple/login',
          {'identityToken': identity, 'nonce': challenge['nonce']});
      await widget.api.saveSession(result['token'] as String);
      if (mounted) await widget.onAuthenticated();
    } catch (_) {
      if (mounted) {
        setState(() => error = t('Apple 登录未完成，请检查配置或重试。',
            'Apple sign-in did not complete. Check configuration or retry.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AutofillGroup(
              child: Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const Icon(Icons.pets, size: 56),
                    const SizedBox(height: 16),
                    Text(
                        registering
                            ? t('创建爪伴账号', 'Create your PetCare account')
                            : t('欢迎回来', 'Welcome back'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        widget.binding
                            ? t('绑定后保留所有现有资料。',
                                'Your existing data stays with this account.')
                            : t('登录后，与家人一起照顾宠物。',
                                'Sign in to care for your pets together.'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (registering) ...[
                      TextFormField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 40,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText: t('照护称呼', 'Caregiver name')),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? t('请输入称呼', 'Enter your name')
                              : null),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration:
                            InputDecoration(labelText: t('邮箱', 'Email')),
                        validator: (v) => v == null ||
                                v.trim().length > 254 ||
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(v.trim())
                            ? t('请输入有效邮箱', 'Enter a valid email')
                            : null),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: password,
                        enabled: !busy,
                        obscureText: hidden,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          registering
                              ? AutofillHints.newPassword
                              : AutofillHints.password
                        ],
                        decoration: InputDecoration(
                            labelText: t('密码', 'Password'),
                            helperText: registering
                                ? t('至少 10 位，最多 72 字节',
                                    'At least 10 characters, at most 72 bytes')
                                : null,
                            suffixIcon: IconButton(
                                tooltip: t('显示或隐藏密码', 'Show or hide password'),
                                onPressed: () =>
                                    setState(() => hidden = !hidden),
                                icon: Icon(hidden
                                    ? Icons.visibility
                                    : Icons.visibility_off))),
                        validator: (v) => v == null ||
                                v.isEmpty ||
                                (registering && v.length < 10) ||
                                utf8.encode(v).length > 72
                            ? t('请检查密码长度', 'Check password length')
                            : null,
                        onFieldSubmitted: (_) {
                          if (!registering) submit();
                        }),
                    const SizedBox(height: 16),
                    if (registering) ...[
                      TextFormField(
                          controller: confirmation,
                          enabled: !busy,
                          obscureText: true,
                          decoration: InputDecoration(
                              labelText: t('确认密码', 'Confirm password')),
                          validator: (v) => v != password.text
                              ? t('两次密码不一致', 'Passwords do not match')
                              : null,
                          onFieldSubmitted: (_) => submit()),
                      const SizedBox(height: 16)
                    ],
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(busy
                            ? t('请稍候…', 'Please wait…')
                            : registering
                                ? t('注册并登录', 'Create account')
                                : t('登录', 'Sign in'))),
                    if (!widget.binding && !registering)
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => EmailActionPage(
                                          api: widget.api, recovery: true))),
                          child: Text(t('忘记密码？', 'Forgot password?'))),
                    if (!widget.binding && Platform.isIOS)
                      OutlinedButton(
                          onPressed: busy ? null : apple,
                          child: Text(t('通过 Apple 登录', 'Sign in with Apple'))),
                    if (!widget.binding)
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    registering = !registering;
                                    error = null;
                                    form.currentState?.reset();
                                  }),
                          child: Text(registering
                              ? t('已有账号？去登录',
                                  'Already have an account? Sign in')
                              : t('没有账号？去注册', 'New here? Create an account'))),
                  ])))));
}
