import 'package:flutter/material.dart';
import '../../app/home_shell.dart';

extension PetModule on CareHomeState {
  Future<void> addPet() async {
    final name = TextEditingController();
    String species = 'cat';
    final valid = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(t('添加宠物', 'Add a pet')),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  ]),
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
        await widget.api
            .request('POST', '/pets', {'name': value, 'species': species});
      });
    }
  }

  List<Widget> petView() => [
        Text(t('家里的小伙伴', 'Your companions'),
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        if (pets.isEmpty)
          empty(t('还没有宠物档案', 'No pets yet'),
              t('添加第一位家庭小成员。', 'Add your first companion.'), Icons.pets),
        ...pets.map((pet) => Card(
                child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.pets)),
              title: Text(pet['name'] as String),
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
      ];
}
