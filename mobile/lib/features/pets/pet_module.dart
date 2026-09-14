import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import '../../app/home_shell.dart';
import 'pet_form_dialog.dart';
import 'pet_detail_page.dart';
import 'pet_profile.dart';
import 'pet_cover.dart';

extension PetModule on CareHomeState {
  Future<String?> pickPetPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return null;
      final decoded = image_lib.decodeImage(await picked.readAsBytes());
      if (decoded == null) throw const FormatException('invalid image');
      var photo = image_lib.bakeOrientation(decoded);
      if (photo.width > 1600) {
        photo = image_lib.copyResize(photo,
            width: 1600, interpolation: image_lib.Interpolation.linear);
      }
      var bytes = image_lib.encodeJpg(photo, quality: 82);
      if (bytes.length > 1100000) {
        photo = image_lib.copyResize(photo,
            width: 1100, interpolation: image_lib.Interpolation.linear);
        bytes = image_lib.encodeJpg(photo, quality: 72);
      }
      final encoded = base64Encode(bytes);
      if (encoded.length > 1500000) {
        throw const FormatException('image too large');
      }
      return encoded;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('无法处理这张图片，请选择 JPG 或 PNG 图片。',
                'Could not process this image. Choose a JPG or PNG image.'))));
      }
      return null;
    }
  }

  Future<void> addPet() => showPetForm();

  Future<void> editPet(Map<String, dynamic> pet) => showPetForm(pet);

  Future<void> showPetForm([Map<String, dynamic>? pet]) async {
    final id = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PetFormDialog(home: this, pet: pet));
    if (id != null && mounted) {
      if (pet == null) updateUi(() => selectedPetId = id);
      await perform(() async {});
    }
  }

  Future<void> openPetDetails(Map<String, dynamic> pet) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PetDetailPage(home: this, petId: pet['id'] as String)));
  }

  String petSpeciesLabel(Map<String, dynamic> pet) => switch (pet['species']) {
        'cat' => t('猫', 'Cat'),
        'dog' => t('狗', 'Dog'),
        _ => t('其他', 'Other'),
      };

  Widget petAvatar(Map<String, dynamic> pet) {
    final photo = pet['photoData'];
    if (photo is String && photo.isNotEmpty) {
      try {
        return CircleAvatar(
            radius: 27, backgroundImage: MemoryImage(base64Decode(photo)));
      } catch (_) {}
    }
    return CircleAvatar(
        radius: 27,
        backgroundColor: pet['species'] == 'dog'
            ? const Color(0xffffd9b8)
            : const Color(0xffdfeaf5),
        child: Icon(
            pet['species'] == 'cat'
                ? Icons.cruelty_free_rounded
                : Icons.pets_rounded,
            color: const Color(0xff694536)));
  }

  Future<bool> deletePetProfile(Map<String, dynamic> pet) async {
    if (!await confirm(
        t('删除宠物？', 'Delete pet?'),
        t('此宠物的档案、照护事项和图文回忆录将一并删除，所有家庭成员都会受影响。',
            'This deletes the pet profile, care tasks and photo memories for everyone.'))) {
      return false;
    }
    var deleted = false;
    await perform(() async {
      await widget.api.request('DELETE', '/pets/${pet['id']}');
      deleted = true;
    });
    return deleted;
  }

  List<Widget> petView() => [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t('我们的毛孩子', 'Our companions'),
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(t('把陪伴的每一天，都好好收藏。', 'Every day together, worth keeping.')),
              ])),
          const SizedBox(width: 8),
          TextButton.icon(
              onPressed: busy ? null : addPet,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(t('添加宠物', 'Add a pet'))),
        ]),
        const SizedBox(height: 24),
        if (pets.isEmpty)
          empty(
              t('第一位小伙伴，等你来介绍', 'Meet your first companion'),
              t('添加照片和名字，开启属于你们的故事。',
                  'Add a photo and name to start your story.'),
              Icons.pets_rounded),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 330
              ? 1
              : constraints.maxWidth >= 650
                  ? 3
                  : 2;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
              spacing: 16,
              runSpacing: 20,
              children: pets.indexed.map((entry) {
                final pet = entry.$2;
                return SizedBox(
                    width: width,
                    child: Material(
                      color: entry.$1.isEven
                          ? const Color(0xfffff0df)
                          : const Color(0xffeaf2f7),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('pet-card-${pet['id']}'),
                        onTap: () => openPetDetails(pet),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                  aspectRatio: 1.05, child: PetCover(pet: pet)),
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                              child: Text(pet['name'] as String,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge)),
                                          const Icon(
                                              Icons.arrow_outward_rounded,
                                              size: 18)
                                        ]),
                                        const SizedBox(height: 6),
                                        Text(
                                            '${petSpeciesLabel(pet)} · ${petAgeLabel(pet['birthDate'] as String?, DateTime.now(), chinese: zh)}',
                                            maxLines: 2,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        const SizedBox(height: 14),
                                        Row(children: [
                                          const Icon(
                                              Icons.auto_stories_outlined,
                                              size: 16),
                                          const SizedBox(width: 5),
                                          Expanded(
                                              child: Text(
                                                  t('${pet['memoryCount'] ?? 0} 篇小回忆',
                                                      '${pet['memoryCount'] ?? 0} memories'),
                                                  style: const TextStyle(
                                                      fontSize: 12)))
                                        ]),
                                      ])),
                            ]),
                      ),
                    ));
              }).toList());
        }),
        const SizedBox(height: 28),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xfff7f2ec),
                borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              const Icon(Icons.favorite_border_rounded,
                  color: Color(0xffce6b4c)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(t('点击小伙伴的卡片，看看档案，写下一段新回忆。',
                      'Open a companion’s card to view their profile and add a memory.')))
            ])),
      ];
}
