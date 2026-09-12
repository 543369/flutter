import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import '../../app/home_shell.dart';

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

  Future<void> addPet() async {
    final name = TextEditingController();
    String species = 'cat';
    String? photoData;
    final valid = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(t('添加宠物', 'Add a pet')),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (photoData != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(base64Decode(photoData!),
                                width: 150, height: 110, fit: BoxFit.cover)),
                      ),
                    OutlinedButton.icon(
                        onPressed: () async {
                          final photo = await pickPetPhoto();
                          if (photo != null) update(() => photoData = photo);
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(t('选择宠物照片', 'Choose pet photo'))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: name,
                        maxLength: 60,
                        decoration: InputDecoration(labelText: t('名字', 'Name')),
                        onChanged: (_) => update(() {})),
                    DropdownButton<String>(
                        value: species,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                              value: 'cat', child: Text(t('猫', 'Cat'))),
                          DropdownMenuItem(
                              value: 'dog', child: Text(t('狗', 'Dog'))),
                          DropdownMenuItem(
                              value: 'other', child: Text(t('其他', 'Other'))),
                        ],
                        onChanged: (v) => update(() => species = v!)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('取消', 'Cancel'))),
                    FilledButton(
                        onPressed: name.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                        child: Text(t('保存', 'Save')))
                  ],
                )));
    final value = name.text.trim();
    if (valid == true) {
      await perform(() async {
        await widget.api.request('POST', '/pets', {
          'name': value,
          'species': species,
          'photoData': photoData,
        });
      });
    }
  }

  Future<void> editPet(Map<String, dynamic> pet) async {
    final name = TextEditingController(text: pet['name'] as String);
    String species = pet['species'] as String;
    String? photoData = pet['photoData'] as String?;
    final valid = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(t('编辑宠物档案', 'Edit pet profile')),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (photoData != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(base64Decode(photoData!),
                                width: 180, height: 125, fit: BoxFit.cover)),
                      ),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () async {
                                final photo = await pickPetPhoto();
                                if (photo != null) {
                                  update(() => photoData = photo);
                                }
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(t('更换照片', 'Change photo')))),
                      if (photoData != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                            tooltip: t('移除照片', 'Remove photo'),
                            onPressed: () => update(() => photoData = null),
                            icon: const Icon(Icons.delete_outline_rounded)),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: name,
                        maxLength: 60,
                        decoration: InputDecoration(labelText: t('名字', 'Name')),
                        onChanged: (_) => update(() {})),
                    DropdownButton<String>(
                        value: species,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                              value: 'cat', child: Text(t('猫', 'Cat'))),
                          DropdownMenuItem(
                              value: 'dog', child: Text(t('狗', 'Dog'))),
                          DropdownMenuItem(
                              value: 'other', child: Text(t('其他', 'Other'))),
                        ],
                        onChanged: (value) => update(() => species = value!)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('取消', 'Cancel'))),
                    FilledButton(
                        onPressed: name.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                        child: Text(t('保存', 'Save'))),
                  ],
                )));
    if (valid == true) {
      await perform(() async {
        await widget.api.request('PATCH', '/pets/${pet['id']}', {
          'name': name.text.trim(),
          'species': species,
          'photoData': photoData,
        });
      });
    }
  }

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
              onTap: busy ? null : () => editPet(pet),
              contentPadding: const EdgeInsets.all(18),
              leading: petAvatar(pet),
              title: Text(pet['name'] as String,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              subtitle: Text(pet['species'] == 'cat'
                  ? t('猫', 'Cat')
                  : pet['species'] == 'dog'
                      ? t('狗', 'Dog')
                      : t('其他', 'Other')),
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
