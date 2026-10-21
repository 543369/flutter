import '../../core/widgets/app_select.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import 'pet_module.dart';
import 'pet_profile.dart';
import 'pet_cover.dart';
import '../subjects/subject_scenarios.dart';

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
  late String subjectType = widget.pet?['subjectType'] as String? ?? 'PET';
  late final relationship =
      TextEditingController(text: widget.pet?['relationship'] as String?);
  late String lifeStage = widget.pet?['lifeStage'] as String? ?? 'OTHER';
  late final Set<String> scenarios =
      (widget.pet == null ? ['DAILY'] : scenariosFor(widget.pet)).toSet();
  String consentBasis = 'SELF';
  bool consentConfirmed = false;
  bool get human => subjectType == 'HUMAN';
  bool saving = false, picking = false;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);

  @override
  void dispose() {
    name.dispose();
    relationship.dispose();
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
    if (human &&
        (relationship.text.trim().isEmpty ||
            (widget.pet == null && !consentConfirmed))) {
      setState(() => error = t('请填写关系并确认资料授权。',
          'Enter the relationship and confirm authorization.'));
      return;
    }
    if (human && scenarios.isEmpty) {
      setState(() =>
          error = t('请至少选择一种照护场景。', 'Select at least one care scenario.'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final response = await widget.home.widget.api.request(
          widget.pet == null ? 'POST' : 'PATCH',
          human
              ? (widget.pet == null
                  ? '/subjects'
                  : '/subjects/${widget.pet!['id']}')
              : (widget.pet == null ? '/pets' : '/pets/${widget.pet!['id']}'),
          {
            'name': name.text.trim(),
            if (human) ...{
              'relationship': relationship.text.trim(),
              'consentBasis': consentBasis,
              'consentConfirmed': consentConfirmed,
              'lifeStage': lifeStage,
              'careScenarios':
                  careScenarios.keys.where(scenarios.contains).toList(),
            },
            if (!human) 'species': species,
            if (!human) 'photos': photos,
            if (!human) 'photoData': photos.firstOrNull,
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
            ? t('添加照护对象', 'Add care profile')
            : human
                ? t('编辑家人档案', 'Edit family profile')
                : t('编辑宠物档案', 'Edit pet profile'),
        subtitle: t('为家人或宠物建立档案，按各自需要安排照护。',
            'Create a profile for a person or pet and plan their care.'),
        saving: saving || picking,
        error: error,
        onSave: name.text.trim().isEmpty ? null : save,
        saveLabel: t('保存', 'Save'),
        cancelLabel: t('取消', 'Cancel'),
        children: [
          if (widget.pet == null) ...[
            AppSelect<String>(
                key: const ValueKey('subject-type'),
                initialValue: subjectType,
                decoration:
                    InputDecoration(labelText: t('照护对象类型', 'Profile type')),
                items: [
                  DropdownMenuItem(value: 'PET', child: Text(t('宠物', 'Pet'))),
                  DropdownMenuItem(
                      value: 'HUMAN', child: Text(t('家人', 'Person')))
                ],
                onChanged:
                    saving ? null : (v) => setState(() => subjectType = v!)),
            const SizedBox(height: AppSpacing.item),
          ],
          if (!human) ...[
            Text(
                t('宠物照片 · ${photos.length}/5',
                    'Pet photos · ${photos.length}/5'),
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
                                  if (human) ...{
                                    'relationship': relationship.text.trim(),
                                    'consentBasis': consentBasis,
                                    'consentConfirmed': consentConfirmed
                                  },
                                  if (!human) 'species': species,
                                  'photos': [entry.$2]
                                })),
                            Align(
                                alignment: Alignment.topRight,
                                child: IconButton.filledTonal(
                                    key: ValueKey(
                                        'remove-pet-photo-${entry.$1}'),
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
                onPressed: saving || picking || photos.length >= 5
                    ? null
                    : choosePhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(photos.length >= 5
                    ? t('已添加 5 张照片', '5 photos added')
                    : t('添加宠物照片', 'Add pet photo'))),
            const SizedBox(height: AppSpacing.content),
          ],
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
          if (!human)
            AppSelect<String>(
                initialValue: species,
                decoration: InputDecoration(
                    labelText: t('种类', 'Species'),
                    prefixIcon: const Icon(Icons.pets_outlined)),
                items: [
                  DropdownMenuItem(value: 'cat', child: Text(t('猫', 'Cat'))),
                  DropdownMenuItem(value: 'dog', child: Text(t('狗', 'Dog'))),
                  DropdownMenuItem(
                      value: 'other', child: Text(t('其他', 'Other'))),
                ],
                onChanged: saving ? null : (v) => setState(() => species = v!)),
          if (human) ...[
            AppSelect<String>(
                key: const ValueKey('subject-life-stage'),
                initialValue: lifeStage,
                decoration: InputDecoration(labelText: t('家人阶段', 'Life stage')),
                items: [
                  for (final e in lifeStages.entries)
                    DropdownMenuItem(
                        value: e.key,
                        child: Text(widget.home.zh ? e.value.$1 : e.value.$2))
                ],
                onChanged:
                    saving ? null : (v) => setState(() => lifeStage = v!)),
            const SizedBox(height: AppSpacing.item),
            Text(t('照护场景（可多选）', 'Care scenarios (select more than one)'),
                style: Theme.of(context).textTheme.titleMedium),
            Wrap(spacing: AppSpacing.inline, children: [
              for (final e in careScenarios.entries)
                FilterChip(
                    key: ValueKey('subject-scenario-${e.key}'),
                    label: Text(widget.home.zh ? e.value.$1 : e.value.$2),
                    selected: scenarios.contains(e.key),
                    onSelected: saving
                        ? null
                        : (selected) => setState(() {
                              if (selected) {
                                scenarios.add(e.key);
                              } else {
                                scenarios.remove(e.key);
                              }
                            }))
            ]),
            Text(t('场景只调整可选模板，不会删除或改写已有安排。具体喂养量、剂量和训练强度请按已有指导自行填写。',
                'Scenarios change available templates, not existing plans. Enter feeding amounts, doses and exercise details from existing instructions.')),
            const SizedBox(height: AppSpacing.item),
            TextField(
                key: const ValueKey('subject-relationship'),
                controller: relationship,
                maxLength: 60,
                enabled: !saving,
                decoration: InputDecoration(
                    labelText: t('与照护者的关系', 'Relationship'),
                    hintText:
                        t('例如：本人、母亲、父亲', 'For example: self, mother, father'))),
            if (widget.pet == null) ...[
              AppSelect<String>(
                  initialValue: consentBasis,
                  decoration: InputDecoration(
                      labelText: t('资料授权依据', 'Authorization basis')),
                  items: [
                    DropdownMenuItem(
                        value: 'SELF',
                        child: Text(t('本人建立自己的档案', 'My own profile'))),
                    DropdownMenuItem(
                        value: 'REPRESENTATIVE',
                        child: Text(t('已获本人同意或有权代表',
                            'Consent or authorized representative')))
                  ],
                  onChanged:
                      saving ? null : (v) => setState(() => consentBasis = v!)),
              CheckboxListTile(
                  key: const ValueKey('subject-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: consentConfirmed,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => consentConfirmed = v!),
                  title: Text(t('我确认已获得必要授权，同意为照护目的保存这些资料。',
                      'I confirm authorization to store this information for care.')),
                  subtitle: Text(t('默认仅自己可见，创建后可逐人授权。请勿录入无权分享的资料。',
                      'Private by default. Share with individual household members after creation.'))),
            ],
          ],
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
                  labelText: human
                      ? t('照护偏好与注意事项', 'Care preferences and notes')
                      : t('简介', 'Biography'),
                  hintText: t('性格、喜好、相遇的故事……',
                      'Personality, favourite things, how you met…'))),
          Text(t('年龄会随出生日期自动更新，创建时间由系统记录。',
              'Age updates from the birth date. The creation time is recorded automatically.')),
        ],
      );
}
