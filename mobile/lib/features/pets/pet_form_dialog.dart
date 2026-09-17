import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import 'pet_module.dart';
import 'pet_profile.dart';
import 'pet_cover.dart';

class PetFormDialog extends StatefulWidget {
  const PetFormDialog(
      {super.key, required this.home, this.pet, this.photoPicker});
  final CareHomeState home;
  final Map<String, dynamic>? pet;
  final Future<String?> Function()? photoPicker;
  @override
  State<PetFormDialog> createState() => _PetFormDialogState();
}

class _PetFormDialogState extends State<PetFormDialog> {
  late final name = TextEditingController(text: widget.pet?['name'] as String?);
  late final biography =
      TextEditingController(text: widget.pet?['biography'] as String?);
  late String species = widget.pet?['species'] as String? ?? 'cat';
  late List<String> photos = petPhotos(widget.pet);
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
    if (picking || saving || photos.length >= 5) return;
    setState(() => picking = true);
    try {
      final photo = await (widget.photoPicker ?? widget.home.pickPetPhoto)();
      if (mounted && photo != null) setState(() => photos.add(photo));
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => picking = false);
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
        'photos': photos,
        'photoData': photos.firstOrNull,
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
          Text(
              t('宠物照片 · ${photos.length}/5', 'Pet photos · ${photos.length}/5'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.inline),
          Text(t('第一张作为封面，首页可左右滑动查看全部照片。',
              'The first photo is the cover. Swipe through all photos on the home screen.')),
          const SizedBox(height: AppSpacing.item),
          Wrap(spacing: 10, runSpacing: 12, children: [
            for (final entry in photos.indexed)
              SizedBox(
                  width: 92,
                  child: Column(children: [
                    SizedBox(
                        height: 92,
                        child: Stack(fit: StackFit.expand, children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: PetCover(pet: {
                                'species': species,
                                'photos': [entry.$2]
                              })),
                          Align(
                              alignment: Alignment.topRight,
                              child: IconButton.filledTonal(
                                  key: ValueKey('remove-pet-photo-${entry.$1}'),
                                  tooltip: t('移除照片', 'Remove photo'),
                                  constraints: const BoxConstraints.tightFor(
                                      width: 32, height: 32),
                                  padding: EdgeInsets.zero,
                                  onPressed: saving || picking
                                      ? null
                                      : () => setState(
                                          () => photos.removeAt(entry.$1)),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18))),
                        ])),
                    TextButton(
                        key: ValueKey('cover-pet-photo-${entry.$1}'),
                        onPressed: saving || picking || entry.$1 == 0
                            ? null
                            : () => setState(() {
                                  photos.insert(0, photos.removeAt(entry.$1));
                                }),
                        child: Text(
                            entry.$1 == 0
                                ? t('封面', 'Cover')
                                : t('设为封面', 'Set cover'),
                            style: const TextStyle(fontSize: 12))),
                  ])),
          ]),
          OutlinedButton.icon(
              key: const ValueKey('add-pet-photo'),
              onPressed:
                  saving || picking || photos.length >= 5 ? null : choosePhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(photos.length >= 5
                  ? t('已添加 5 张照片', '5 photos added')
                  : t('添加宠物照片', 'Add pet photo'))),
          const SizedBox(height: AppSpacing.content),
          TextField(
              key: const ValueKey('pet-name'),
              controller: name,
              enabled: !saving,
              maxLength: 60,
              decoration: InputDecoration(
                  labelText: t('名字', 'Name'),
                  hintText: t('小伙伴叫什么？', 'What is their name?')),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.inline),
          DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Theme.of(context).colorScheme.surface,
              elevation: 3,
              icon: const Icon(Icons.expand_more_rounded, size: 20),
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
          const SizedBox(height: AppSpacing.content),
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
