import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../pets/pet_module.dart';
import 'task_form_dialog.dart';

extension CareActions on CareHomeState {
  Future<void> addTask() async {
    if (pets.isEmpty) {
      await addPet();
      return;
    }
    final petId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TaskFormDialog(home: this));
    if (petId != null && mounted) {
      updateUi(() => selectedPetId = petId);
      await perform(() async {});
    }
  }

  Future<void> changeCompletion(
      Map<String, dynamic> task, bool complete) async {
    if (!complete &&
        !await confirm(
            t('撤销这次完成？', 'Undo completion?'),
            t('将重新标为待照护，并保留撤销记录。',
                'This becomes pending again. An undo event stays in history.'))) {
      return;
    }
    await perform(() async {
      await widget.api
          .request('PATCH', "/tasks/${task['id']}", {'completed': complete});
    });
  }
}
