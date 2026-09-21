import 'dart:convert';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'member_avatar.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';

Future<String?> _pickAvatar() async {
  final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85);
  if (picked == null) return null;
  final decoded = image_lib.decodeImage(await picked.readAsBytes());
  if (decoded == null) throw const FormatException('invalid image');
  final oriented = image_lib.bakeOrientation(decoded);
  final side =
      oriented.width < oriented.height ? oriented.width : oriented.height;
  final cropped = image_lib.copyCrop(oriented,
      x: (oriented.width - side) ~/ 2,
      y: (oriented.height - side) ~/ 2,
      width: side,
      height: side);
  final resized = image_lib.copyResize(cropped, width: 256, height: 256);
  return base64Encode(image_lib.encodeJpg(resized, quality: 85));
}

class PersonalProfilePage extends StatefulWidget {
  const PersonalProfilePage({super.key, required this.home});
  final CareHomeState home;
  @override
  State<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends State<PersonalProfilePage> {
  Map<String, dynamic>? profile;
  String? error;
  bool loading = true;
  bool uploading = false;
  String t(String zh, String en) => widget.home.t(zh, en);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.home.widget.api.request('GET', '/profile');
      if (mounted) {
        setState(() => profile = Map<String, dynamic>.from(value as Map));
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit() async {
    final saved = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ProfileEditor(home: widget.home, profile: profile!));
    if (saved != null && mounted) {
      setState(() => profile = saved);
      await widget.home.perform(() async {});
    }
  }

  Future<void> uploadAvatar() async {
    if (uploading) return;
    setState(() => uploading = true);
    try {
      final encoded = await _pickAvatar();
      if (encoded == null || !mounted) return;
      final result = await widget.home.widget.api
          .request('PUT', '/profile/avatar', {'avatarData': encoded});
      if (!mounted) return;
      setState(() => profile = Map<String, dynamic>.from(result as Map));
      await widget.home.perform(() async {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('头像上传失败，请重新选择图片并重试。',
                'Could not upload your avatar. Choose an image and try again.'))));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 21, color: const Color(0xff9a7560)),
        const SizedBox(width: AppSpacing.item),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xff8b7a70))),
          const SizedBox(height: AppSpacing.inline),
          SelectableText(value, style: const TextStyle(fontSize: 16)),
        ])),
      ]));
  String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return t('未记录', 'Not recorded');
    final local = parsed.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('个人资料', 'Personal profile'))),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!),
                    TextButton(onPressed: load, child: Text(t('重试', 'Retry')))
                  ]))
                : Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: ListView(
                            padding: AppSpacing.dialogInsets,
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                      color: const Color(0xffffefcc),
                                      borderRadius: BorderRadius.circular(28)),
                                  child: Column(children: [
                                    Semantics(
                                      button: true,
                                      label: t('更换头像', 'Change avatar'),
                                      child: InkWell(
                                        onTap: uploading ? null : uploadAvatar,
                                        customBorder: const CircleBorder(),
                                        child: MemberAvatar(
                                            data: profile!['avatarData']
                                                as String?,
                                            radius: 36),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed:
                                          uploading ? null : uploadAvatar,
                                      icon: uploading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(
                                              Icons.add_a_photo_outlined,
                                              size: 18),
                                      label: Text(uploading
                                          ? t('上传中…', 'Uploading…')
                                          : t('更换头像', 'Change avatar')),
                                    ),
                                    const SizedBox(height: AppSpacing.content),
                                    Text(profile!['name'] as String,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: AppSpacing.inline),
                                    Text(
                                        t('每一份陪伴，都有你的名字。',
                                            'Every little act of care carries your name.'),
                                        textAlign: TextAlign.center),
                                    const SizedBox(height: AppSpacing.section),
                                    FilledButton.icon(
                                        onPressed: uploading ? null : edit,
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18),
                                        label: Text(t('编辑资料', 'Edit profile'))),
                                  ])),
                              const SizedBox(height: AppSpacing.section),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: const Color(0xfff8f1e9),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Column(children: [
                                    row(
                                        Icons.alternate_email,
                                        t('登录账号', 'Account'),
                                        profile!['account'] == 'DEVICE'
                                            ? t('设备账号（尚未绑定）',
                                                'Device account (not linked)')
                                            : profile!['account'] as String),
                                    const Divider(height: 1),
                                    row(
                                        Icons.cake_outlined,
                                        t('生日', 'Birthday'),
                                        profile!['birthDate'] as String? ??
                                            t('未填写', 'Not added')),
                                    const Divider(height: 1),
                                    row(
                                        Icons.phone_outlined,
                                        t('手机号', 'Phone number'),
                                        profile!['phone'] as String? ??
                                            t('未填写', 'Not added')),
                                    const Divider(height: 1),
                                    row(Icons.schedule, t('创建时间', 'Created'),
                                        date(profile!['createdAt'])),
                                    const Divider(height: 1),
                                    row(
                                        Icons.badge_outlined,
                                        t('账号 ID', 'Account ID'),
                                        profile!['id'] as String),
                                  ])),
                              const SizedBox(height: AppSpacing.content),
                              Text(
                                  t('你的手机号仅本人可见，不向其他家庭成员展示，包括管理员和临时照护者。你可以随时在编辑资料中删除手机号。生日也仅本人可见。手机号由服务端保存，尚未验证，不用于登录或找回密码。',
                                      'Your phone number is visible only to you in the app, not to other household members, administrators or temporary caregivers. You can remove it in Edit profile at any time. Your birthday is also private. Your phone is stored on the server and is unverified; it is not used for sign-in or account recovery.'),
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xff8b7a70))),
                            ]))),
      );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.home, required this.profile});
  final CareHomeState home;
  final Map<String, dynamic> profile;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: widget.profile['name'] as String);
  late final phone =
      TextEditingController(text: widget.profile['phone'] as String? ?? '');
  late DateTime? birthday =
      DateTime.tryParse(widget.profile['birthDate'] as String? ?? '');
  bool saving = false;
  bool pickingAvatar = false;
  String? selectedAvatar;
  bool get busy => saving || pickingAvatar;

  Future<void> pickAvatar() async {
    setState(() {
      pickingAvatar = true;
      error = null;
    });
    try {
      final value = await _pickAvatar();
      if (mounted && value != null) setState(() => selectedAvatar = value);
    } catch (_) {
      if (mounted) {
        setState(() => error = t('无法读取图片，请重新选择。',
            'Could not read this image. Please choose another.'));
      }
    } finally {
      if (mounted) setState(() => pickingAvatar = false);
    }
  }

  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final value = await showDatePicker(
        context: context,
        initialDate: birthday ?? DateTime(now.year - 20, now.month, now.day),
        firstDate: DateTime(1900),
        lastDate: now,
        helpText: t('选择生日', 'Choose birthday'));
    if (value != null && mounted) setState(() => birthday = value);
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (selectedAvatar != null) {
        await widget.home.widget.api
            .request('PUT', '/profile/avatar', {'avatarData': selectedAvatar});
      }
      final value = await widget.home.widget.api.request('PATCH', '/profile', {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'birthDate': birthday == null
            ? null
            : '${birthday!.year}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
      });
      if (mounted) {
        Navigator.pop(context, Map<String, dynamic>.from(value as Map));
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                  padding: AppSpacing.dialogInsets,
                  child: Form(
                      key: form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('让家人更熟悉你', 'A little more about you'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: AppSpacing.inline),
                            Text(t('完善资料，留下属于你的陪伴印记。',
                                'Make your profile feel like you.')),
                            const SizedBox(height: AppSpacing.section),
                            Center(
                                child: Column(children: [
                              MemberAvatar(
                                  data: selectedAvatar ??
                                      widget.profile['avatarData'] as String?,
                                  radius: 36),
                              TextButton.icon(
                                  onPressed: busy ? null : pickAvatar,
                                  icon: const Icon(Icons.add_a_photo_outlined,
                                      size: 18),
                                  label: Text(pickingAvatar
                                      ? t('读取中…', 'Loading…')
                                      : t('更换头像', 'Change avatar'))),
                            ])),
                            const SizedBox(height: AppSpacing.item),
                            TextFormField(
                                controller: name,
                                enabled: !busy,
                                maxLength: 40,
                                decoration: InputDecoration(
                                    labelText: t('照护称呼', 'Caregiver name'),
                                    prefixIcon:
                                        const Icon(Icons.person_outline)),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? t('请输入称呼', 'Enter a name')
                                    : null),
                            const SizedBox(height: AppSpacing.item),
                            Row(children: [
                              Expanded(
                                  child: OutlinedButton.icon(
                                      onPressed: busy ? null : pickBirthday,
                                      icon: const Icon(Icons.cake_outlined),
                                      label: Text(birthday == null
                                          ? t('选择生日（选填）', 'Birthday (optional)')
                                          : '${birthday!.year}/${birthday!.month}/${birthday!.day}'))),
                              if (birthday != null)
                                IconButton(
                                    onPressed: busy
                                        ? null
                                        : () => setState(() => birthday = null),
                                    tooltip: t('清除生日', 'Clear birthday'),
                                    icon: const Icon(Icons.close))
                            ]),
                            const SizedBox(height: AppSpacing.content),
                            TextFormField(
                                controller: phone,
                                enabled: !busy,
                                maxLength: 25,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                    labelText: t('手机号（选填）', 'Phone (optional)'),
                                    hintText: '+86 138 0000 0000',
                                    helperText: t('仅本人可见，不向其他家庭成员展示。可随时清除。',
                                        'Only you can view this in the app. Hidden from other household members. You can remove it anytime.'),
                                    helperMaxLines: 4,
                                    prefixIcon:
                                        const Icon(Icons.phone_outlined)),
                                validator: (v) => v != null &&
                                        v.trim().isNotEmpty &&
                                        !RegExp(r'^[+]?[0-9][0-9 ()-]{5,24}$')
                                            .hasMatch(v.trim())
                                    ? t('请输入有效的手机号，可包含国家区号',
                                        'Enter a phone number, including country code if needed')
                                    : null),
                            if (error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: AppSpacing.section),
                            Row(children: [
                              Expanded(
                                  child: TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: Text(t('取消', 'Cancel')))),
                              const SizedBox(width: AppSpacing.item),
                              Expanded(
                                  child: FilledButton(
                                      onPressed: busy ? null : save,
                                      child: Text(saving
                                          ? t('保存中…', 'Saving…')
                                          : t('保存资料', 'Save profile'))))
                            ]),
                          ]))))));
}
