import 'dart:async';
import '../../core/theme/app_spacing.dart';
import '../../core/config/app_features.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'email_action_page.dart';
import 'package:flutter/material.dart';
import '../../core/network/care_api.dart';
import '../../core/widgets/brand_motion.dart';

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
  final verificationCode = TextEditingController();
  Timer? resendTimer;
  int cooldown = 0;
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      confirmation = TextEditingController();
  late bool registering = widget.binding;
  bool busy = false, hidden = true, sendingCode = false;
  String? error;
  String t(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  @override
  void dispose() {
    resendTimer?.cancel();
    verificationCode.dispose();
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
        await widget.api.registerVerified(
            email.text, password.text, name.text, verificationCode.text);
      } else {
        await widget.api.login(email.text, password.text);
      }
      if (mounted && registering) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('注册成功！昵称可在「家庭 → 个人资料 → 编辑资料」修改。',
                'Welcome! Change your nickname in Family → Personal profile → Edit profile.'))));
      }
      if (mounted) await widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is PlatformException
            ? t('无法保存登录凭据，请检查系统钥匙串权限。',
                'Cannot save sign-in credentials. Check system keychain permissions.')
            : e is ApiError
                ? e.code == 'REGISTRATION_CODE_INVALID'
                    ? t('验证码不正确或已过期，请检查邮箱并重新发送。',
                        'Invalid or expired code. Check your email or request a new code.')
                    : e.status == 401
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

  Future<void> sendRegistrationCode() async {
    if (busy || cooldown > 0) return;
    final address = email.text.trim();
    if (address.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      setState(() => error = t('请输入正确的邮箱格式，例如 name@example.com',
          'Enter a valid email address, e.g. name@example.com'));
      return;
    }
    setState(() {
      busy = true;
      sendingCode = true;
      error = null;
    });
    try {
      await widget.api
          .request('POST', '/auth/register/request', {'email': address});
      if (!mounted) return;
      verificationCode.clear();
      setState(() => cooldown = 60);
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => cooldown--);
        if (cooldown <= 0) timer.cancel();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('验证码已发送，请检查邮箱并粘贴完整验证码。',
              'Code sent. Check your email and paste the complete code.'))));
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiError && e.status == 429
            ? t('发送过于频繁，请一分钟后重试。',
                'Please wait a minute before requesting another code.')
            : e is ApiError && e.status == 409
                ? t('该邮箱已注册，请直接登录。',
                    'This email is registered. Please sign in.')
                : t('邮件发送失败，请稍后重试。',
                    'Could not send email. Please try again later.'));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          sendingCode = false;
        });
      }
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
      if (mounted && registering) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('注册成功！昵称可在「家庭 → 个人资料 → 编辑资料」修改。',
                'Welcome! Change your nickname in Family → Personal profile → Edit profile.'))));
      }
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
                  child: ListView(padding: AppSpacing.pageInsets, children: [
                    const PawMark(size: 44),
                    const SizedBox(height: AppSpacing.content),
                    Text(
                        registering
                            ? t('创建家庭照护账号', 'Create your Family Care account')
                            : t('欢迎回来', 'Welcome back'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.inline),
                    Text(
                        widget.binding
                            ? t('绑定后保留所有现有资料。',
                                'Your existing data stays with this account.')
                            : t('一起照顾家人和宠物，记录每一次用心。',
                                'Sign in to care for your pets together.'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.section),
                    if (registering) ...[
                      TextFormField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 40,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText:
                                  t('照护称呼（选填）', 'Caregiver name (optional)'),
                              helperText: t('留空将按设备地区生成昵称，可在家庭 → 个人资料修改。',
                                  'Leave blank for a local nickname. Change it in Family → Personal profile.')),
                          validator: (v) => null),
                      const SizedBox(height: AppSpacing.item),
                    ],
                    TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        autovalidateMode: registering
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                            labelText: t('邮箱', 'Email'),
                            hintText: 'name@example.com',
                            helperMaxLines: 3,
                            errorMaxLines: 2,
                            helperText: registering
                                ? t('请填写本人可接收邮件的邮箱，完成邮箱验证后才能注册。',
                                    'Use an email address you can access. Email verification is required to register.')
                                : null),
                        validator: (v) => v == null ||
                                v.trim().length > 254 ||
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(v.trim())
                            ? t('请输入正确的邮箱格式，例如 name@example.com',
                                'Enter a valid email address, e.g. name@example.com')
                            : null),
                    if (registering) ...[
                      const SizedBox(height: AppSpacing.item),
                      TextFormField(
                        controller: verificationCode,
                        enabled: !busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                            labelText: t('邮箱验证码', 'Email code'),
                            hintText: t('粘贴验证码', 'Paste code'),
                            helperMaxLines: 2,
                            errorMaxLines: 2,
                            helperText: cooldown > 0
                                ? t('已发送，请查收邮件 · 15 分钟内有效',
                                    'Sent to your inbox · Valid for 15 minutes')
                                : t('验证邮箱后即可注册 · 验证码 15 分钟内有效',
                                    'Verify your email to register · Code valid for 15 minutes'),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(6),
                              child: FilledButton.tonal(
                                onPressed: busy || cooldown > 0
                                    ? null
                                    : sendRegistrationCode,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(104, 44),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  backgroundColor: const Color(0xfff1e2d3),
                                  foregroundColor: const Color(0xff684936),
                                  disabledBackgroundColor:
                                      const Color(0xfff1ebe5),
                                  disabledForegroundColor:
                                      const Color(0xff8b7466),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: sendingCode
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(cooldown > 0
                                        ? t('$cooldown 秒后重发',
                                            'Resend in $cooldown s')
                                        : t('发送验证码', 'Send code')),
                              ),
                            )),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? t('请先获取并填写邮箱验证码',
                                'Request and enter the email verification code')
                            : null,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.content),
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
                    const SizedBox(height: AppSpacing.content),
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
                      const SizedBox(height: AppSpacing.content)
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
                    const SizedBox(height: AppSpacing.inline),
                    if (AppFeatures.emailActionsEnabled &&
                        !widget.binding &&
                        !registering)
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => EmailActionPage(
                                          api: widget.api, recovery: true))),
                          child: Text(t('忘记密码？', 'Forgot password?'))),
                    if (!widget.binding &&
                        (!kIsWeb &&
                            defaultTargetPlatform == TargetPlatform.iOS))
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.inline),
                          child: OutlinedButton(
                              onPressed: busy ? null : apple,
                              child: Text(
                                  t('通过 Apple 登录', 'Sign in with Apple')))),
                    if (!widget.binding)
                      TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    registering = !registering;
                                    verificationCode.clear();
                                    error = null;
                                    form.currentState?.reset();
                                  }),
                          child: Text(registering
                              ? t('已有账号？去登录',
                                  'Already have an account? Sign in')
                              : t('没有账号？去注册', 'New here? Create an account'))),
                  ])))));
}
