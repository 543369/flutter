import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../care/care_pages.dart';
import 'pet_module.dart';
import 'pet_profile.dart';

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
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (home.busy) const LinearProgressIndicator(),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: AspectRatio(
                                aspectRatio: 1.5, child: _photo(pet))),
                        const SizedBox(height: 20),
                        Text(pet['name'] as String,
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 8),
                        Text(
                            '${home.petSpeciesLabel(pet)} · ${petAgeLabel(pet['birthDate'] as String?, DateTime.now(), chinese: home.zh)}'),
                        const SizedBox(height: 20),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t('关于我', 'About me'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 8),
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
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed:
                                home.busy ? null : () => home.editPet(pet),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(t('编辑档案', 'Edit profile'))),
                      ],
                    ),
            ))),
          );
        },
      );

  Widget _photo(Map<String, dynamic> pet) {
    final photo = pet['photoData'] as String?;
    Widget fallback() => Container(
        color: const Color(0xffffefcc),
        child:
            const Icon(Icons.pets_rounded, size: 80, color: Color(0xff916b53)));
    if (photo == null || photo.isEmpty) return fallback();
    try {
      return Image.memory(base64Decode(photo),
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback());
    } catch (_) {
      return fallback();
    }
  }
}
