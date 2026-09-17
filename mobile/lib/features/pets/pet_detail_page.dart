import '../../core/theme/app_spacing.dart';
import '../health/health_pages.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../care/care_pages.dart';
import 'pet_module.dart';
import 'pet_profile.dart';
import 'pet_photo_carousel.dart';
import 'memory_pages.dart';

class PetDetailPage extends StatelessWidget {
  const PetDetailPage({super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  String t(String zh, String en) => home.t(zh, en);

  Widget field(String title, String value, IconData icon) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: home.careChanges,
        builder: (context, _) {
          final pet = home.pets.where((p) => p['id'] == petId).firstOrNull;
          return Scaffold(
            appBar: AppBar(title: Text(t('宠物详情', 'Pet profile')), actions: [
              if (pet != null)
                IconButton(
                    tooltip: t('编辑档案', 'Edit profile'),
                    onPressed: home.busy ? null : () => home.editPet(pet),
                    icon: const Icon(Icons.edit_outlined)),
            ]),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: pet == null
                  ? Text(t(
                      '此宠物档案已不存在。', 'This pet profile is no longer available.'))
                  : ListView(
                      padding: AppSpacing.dialogInsets,
                      children: [
                        if (home.busy) const LinearProgressIndicator(),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: AspectRatio(
                                aspectRatio: 1.5,
                                child: PetPhotoCarousel(
                                    pet: pet, openPhotos: true))),
                        const SizedBox(height: AppSpacing.section),
                        Text(pet['name'] as String,
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: AppSpacing.inline),
                        Text(
                            '${home.petSpeciesLabel(pet)} · ${petAgeLabel(pet['birthDate'] as String?, DateTime.now(), chinese: home.zh)}'),
                        const SizedBox(height: AppSpacing.section),
                        Card(
                            color: const Color(0xffe6eee2),
                            child: ListTile(
                                contentPadding:
                                    const EdgeInsets.all(AppSpacing.content),
                                leading: const Icon(
                                    Icons.health_and_safety_outlined),
                                title: Text(t('健康档案', 'Health records')),
                                subtitle: Text(t('疫苗 · 驱虫 · 用药 · 过敏 · 体重 · 就诊',
                                    'Vaccines · Medication · Weight · Vet visits')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => HealthRecordsPage(
                                            home: home, petId: petId))))),
                        const SizedBox(height: AppSpacing.item),
                        Card(
                            color: const Color(0xffffe9df),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => PetMemoriesPage(
                                          home: home, petId: petId))),
                              child: Padding(
                                  padding: AppSpacing.cardInsets,
                                  child: Row(children: [
                                    const Icon(Icons.auto_stories_outlined,
                                        size: 32, color: Color(0xffb75f43)),
                                    const SizedBox(width: AppSpacing.item),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(t('它的回忆录', 'Their memory book'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge),
                                          const SizedBox(
                                              height: AppSpacing.inline),
                                          Text(t(
                                              '${pet['memoryCount'] ?? 0} 篇故事 · 收藏美好日常',
                                              '${pet['memoryCount'] ?? 0} stories · Little moments to keep')),
                                        ])),
                                    const Icon(Icons.chevron_right_rounded),
                                  ])),
                            )),
                        const SizedBox(height: AppSpacing.inline),
                        Card(
                            child: Padding(
                                padding: AppSpacing.cardInsets,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t('关于我', 'About me'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: AppSpacing.inline),
                                      Text((pet['biography'] as String? ?? '')
                                              .trim()
                                              .isEmpty
                                          ? t('还没有简介，添加一点小伙伴的故事吧。',
                                              'No biography yet. Add a little of their story.')
                                          : pet['biography'] as String),
                                    ]))),
                        Card(
                            child: Column(children: [
                          field(
                              t('出生日期', 'Date of birth'),
                              pet['birthDate'] == null
                                  ? t('未填写', 'Not set')
                                  : petBirthLabel(pet['birthDate'] as String),
                              Icons.cake_outlined),
                          field(
                              t('年龄', 'Age'),
                              petAgeLabel(
                                  pet['birthDate'] as String?, DateTime.now(),
                                  chinese: home.zh),
                              Icons.favorite_border_rounded),
                          field(
                              t('创建时间', 'Created'),
                              pet['createdAt'] == null
                                  ? t('未记录（旧档案）',
                                      'Not recorded (older profile)')
                                  : home.dateLabel(
                                      DateTime.parse(pet['createdAt'] as String)
                                          .toLocal()),
                              Icons.event_note_outlined),
                        ])),
                        FilledButton.icon(
                            onPressed: () {
                              home.updateUi(() => home.selectedPetId = petId);
                              home.openSchedules();
                            },
                            icon: const Icon(Icons.event_available_rounded),
                            label: Text(t('查看照护安排', 'View care plans'))),
                        const SizedBox(height: AppSpacing.inline),
                        OutlinedButton.icon(
                            onPressed:
                                home.busy ? null : () => home.editPet(pet),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(t('编辑档案', 'Edit profile'))),
                        const SizedBox(height: AppSpacing.content),
                        TextButton.icon(
                            onPressed: home.busy
                                ? null
                                : () async {
                                    final deleted =
                                        await home.deletePetProfile(pet);
                                    if (deleted && context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(t('删除宠物档案', 'Delete pet profile'))),
                      ],
                    ),
            ))),
          );
        },
      );
}
