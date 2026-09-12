import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import 'pet_module.dart';
import 'pet_profile.dart';

class PetFormDialog extends StatefulWidget {
  const PetFormDialog({super.key, required this.home, this.pet});
  final CareHomeState home;
  final Map<String, dynamic>? pet;
  @override
  State<PetFormDialog> createState() => _PetFormDialogState();
}

class _PetFormDialogState extends State<PetFormDialog> {
  late final name = TextEditingController(text: widget.pet?['name'] as String?);
  late final biography =
      TextEditingController(text: widget.pet?['biography'] as String?);
  late String species = widget.pet?['species'] as String? ?? 'cat';
  late String? photoData = widget.pet?['photoData'] as String?;
  late DateTime? birth =
      DateTime.tryParse(widget.pet?['birthDate'] as String? ?? '');
  bool saving = false, picking = false;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);

  @override
  void dispose() {
    name.dispose();
    biography.dispose();
    super.dispose();
  }

  String? get birthDate => birth == null
      ? null
      : '${birth!.year.toString().padLeft(4, '0')}-${birth!.month.toString().padLeft(2, '0')}-${birth!.day.toString().padLeft(2, '0')}';

  Future<void> choosePhoto() async {
    setState(() => picking = true);
    final photo = await widget.home.pickPetPhoto();
    if (mounted) {
      setState(() {
        picking = false;
        if (photo != null) photoData = photo;
      });
    }
  }

  Future<void> chooseBirth() async {
    final date = await showDatePicker(
        context: context,
        helpText: t('出生日期', 'Date of birth'),
        initialDate: birth ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now());
    if (date != null && mounted) setState(() => birth = date);
  }

  Future<void> save() async {
    if (saving || picking || name.text.trim().isEmpty) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final response = await widget.home.widget.api.request(
          widget.pet == null ? 'POST' : 'PATCH',
          widget.pet == null ? '/pets' : '/pets/${widget.pet!['id']}', {
        'name': name.text.trim(),
        'species': species,
        'photoData': photoData,
        'biography': biography.text.trim(),
        'birthDate': birthDate,
      });
      if (mounted) Navigator.of(context).pop(response['id'] as String);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ProfileDialog(
        title: widget.pet == null
            ? t('添加宠物', 'Add a pet')
            : t('编辑宠物档案', 'Edit pet profile'),
        subtitle: t('认识这位小伙伴，记录一起成长的日子。',
            'Meet your companion and record their story.'),
        saving: saving || picking,
        error: error,
        onSave: name.text.trim().isEmpty ? null : save,
        saveLabel: t('保存', 'Save'),
        cancelLabel: t('取消', 'Cancel'),
        children: [
          Center(
              child: Stack(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: photoData == null || photoData!.isEmpty
                    ? Container(
                        width: 108,
                        height: 108,
                        color: const Color(0xffe3f0fb),
                        child: const Icon(Icons.pets_rounded,
                            size: 46, color: Color(0xff684739)))
                    : Image.memory(base64Decode(photoData!),
                        width: 108,
                        height: 108,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                            width: 108,
                            height: 108,
                            child: Icon(Icons.pets_rounded, size: 46)))),
          ])),
          TextButton.icon(
              onPressed: saving || picking ? null : choosePhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(photoData == null
                  ? t('选择宠物照片', 'Choose pet photo')
                  : t('更换照片', 'Change photo'))),
          if (photoData != null)
            TextButton(
                onPressed:
                    saving ? null : () => setState(() => photoData = null),
                child: Text(t('移除照片', 'Remove photo'))),
          const SizedBox(height: 12),
          TextField(
              key: const ValueKey('pet-name'),
              controller: name,
              enabled: !saving,
              maxLength: 60,
              decoration: InputDecoration(
                  labelText: t('名字', 'Name'),
                  hintText: t('小伙伴叫什么？', 'What is their name?')),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
              initialValue: species,
              decoration: InputDecoration(
                  labelText: t('种类', 'Species'),
                  prefixIcon: const Icon(Icons.pets_outlined)),
              items: [
                DropdownMenuItem(value: 'cat', child: Text(t('猫', 'Cat'))),
                DropdownMenuItem(value: 'dog', child: Text(t('狗', 'Dog'))),
                DropdownMenuItem(value: 'other', child: Text(t('其他', 'Other'))),
              ],
              onChanged: saving ? null : (v) => setState(() => species = v!)),
          const SizedBox(height: 16),
          Card(
              color: const Color(0xfffff3dc),
              child: Column(children: [
                ListTile(
                    key: const ValueKey('pet-birthday'),
                    leading: const Icon(Icons.cake_outlined),
                    title: Text(t('出生日期', 'Date of birth')),
                    subtitle: Text(birth == null
                        ? t('选填，不确定可暂不填写', 'Optional — leave empty if unknown')
                        : petBirthLabel(birthDate)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: saving ? null : chooseBirth),
                if (birth != null)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(t('年龄：', 'Age: ') +
                                petAgeLabel(birthDate, DateTime.now(),
                                    chinese: widget.home.zh))),
                        TextButton(
                            onPressed: saving
                                ? null
                                : () => setState(() => birth = null),
                            child: Text(t('清除', 'Clear')))
                      ])),
              ])),
          TextField(
              key: const ValueKey('pet-biography'),
              controller: biography,
              enabled: !saving,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                  labelText: t('简介', 'Biography'),
                  hintText: t('性格、喜好、相遇的故事……',
                      'Personality, favourite things, how you met…'))),
          Text(t('年龄会随出生日期自动更新，创建时间由系统记录。',
              'Age updates from the birth date. The creation time is recorded automatically.')),
        ],
      );
}
