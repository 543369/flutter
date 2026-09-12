import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import '../../app/home_shell.dart';
import 'pet_form_dialog.dart';
import 'pet_detail_page.dart';
import 'pet_profile.dart';

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

  List<Widget> petView() => [
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: const Color(0xffffedc3),
                borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t('家里的小伙伴', 'Your companions'),
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(t('每一位，都有自己的照护节奏。',
                        'Every companion has their own care rhythm.')),
                  ])),
              Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.pets_rounded,
                      size: 30, color: Color(0xffa25030)))
            ])),
        const SizedBox(height: 18),
        if (pets.isEmpty)
          empty(t('还没有宠物档案', 'No pets yet'),
              t('添加第一位家庭小成员。', 'Add your first companion.'), Icons.pets),
        ...pets.map((pet) => Card(
            color: const Color(0xfffaf1e7),
            child: ListTile(
              onTap: () => openPetDetails(pet),
              contentPadding: const EdgeInsets.all(18),
              leading: petAvatar(pet),
              title: Text(pet['name'] as String,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${petSpeciesLabel(pet)} · ${petAgeLabel(pet['birthDate'] as String?, DateTime.now(), chinese: zh)}'),
              trailing: IconButton(
                  tooltip: t('删除宠物', 'Delete pet'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm(
                              t('删除宠物？', 'Delete pet?'),
                              t('将同时删除此宠物的全部照护事项，所有家庭成员均受影响。',
                                  'All care tasks for this pet will also be deleted for everyone.'))) {
                            await perform(() async {
                              await widget.api
                                  .request('DELETE', '/pets/${pet['id']}');
                            });
                          }
                        }),
            ))),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: busy ? null : addPet,
            icon: const Icon(Icons.add_rounded),
            label: Text(t('添加宠物', 'Add a pet'))),
      ];
}
