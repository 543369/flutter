import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../pets/pet_module.dart';
import 'task_form_dialog.dart';

extension CareActions on CareHomeState {
  Future<void> addTask({Offset? revealOrigin}) async {
    if (pets.isEmpty) {
      await addPet();
      return;
    }
    final petId = revealOrigin == null
        ? await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => TaskFormDialog(home: this))
        : await showGeneralDialog<String>(
            context: context,
            barrierDismissible: false,
            transitionDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            pageBuilder: (context, animation, secondary) =>
                TaskFormDialog(home: this),
            transitionBuilder: (context, animation, secondary, child) =>
                ClipPath(
                    clipper: _CareRevealClipper(revealOrigin,
                        Curves.easeInOutCubic.transform(animation.value)),
                    child: child));
    if (petId != null && mounted) {
      updateUi(() => selectedPetId = petId);
      await perform(() async {});
    }
  }

  Future<void> changeCompletion(Map<String, dynamic> task, bool complete,
      {bool confirmUndo = true}) async {
    if (!complete &&
        confirmUndo &&
        !await confirm(
            t('撤销这次完成？', 'Undo completion?'),
            t('将重新标为待照护，并保留撤销记录。',
                'This becomes pending again. An undo event stays in history.'))) {
      return;
    }
    final id = task['id'] as String;
    if (busy || submittingTasks.contains(id)) return;
    final previousWrites = taskWrites.values.map((c) => c.future).toList();
    final write = Completer<void>();
    taskWrites[id] = write;
    updateUi(() => submittingTasks.add(id));
    await syncDone?.future;
    await Future.wait(previousWrites);
    try {
      if (!mounted) return;
      final response = Map<String, dynamic>.from(await widget.api
          .request('PATCH', '/tasks/$id', {'completed': complete}) as Map);
      if (!mounted) return;
      updateUi(() {
        final candidates = response.remove('reminderTasks');
        final updated = {...task, ...response, 'completed': complete};
        data?['tasks'] = tasks.map((t) => t['id'] == id ? updated : t).toList();
        if (candidates is List) {
          data?['reminderTasks'] = candidates;
        } else if (data?['reminderTasks'] is List) {
          data!['reminderTasks'] = (data!['reminderTasks'] as List)
              .where((t) => t['id'] != id)
              .toList()
            ..add(updated);
        }
        final event = response['lastEvent'];
        if (event is Map) {
          final previous = (data?['history'] as List? ?? [])
              .where((e) => e['id'] != event['id'])
              .toList();
          data?['history'] = [
            {
              ...event,
              'taskId': id,
              'petId': task['petId'],
              'petName': task['petName'],
              'title': task['title'],
              'careType': task['careType']
            },
            ...previous
          ];
        }
      });
      await syncReminders();
      if (mounted && reminderError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('照护状态已保存，但本机提醒未更新，请检查通知权限。',
                'Care saved, but local reminders could not update. Check notification permissions.'))));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t(complete ? '照护已完成' : '已恢复待照护',
              complete ? 'Care completed' : 'Care reopened')),
          action: complete
              ? SnackBarAction(
                  label: t('撤销', 'Undo'),
                  onPressed: () =>
                      changeCompletion(task, false, confirmUndo: false))
              : null,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message(e))));
      }
    } finally {
      taskWrites.remove(id);
      write.complete();
      if (mounted) updateUi(() => submittingTasks.remove(id));
    }
  }
}

class _CareRevealClipper extends CustomClipper<Path> {
  const _CareRevealClipper(this.origin, this.progress);
  final Offset origin;
  final double progress;
  @override
  Path getClip(Size size) {
    final dx = math.max(origin.dx.abs(), (size.width - origin.dx).abs());
    final dy = math.max(origin.dy.abs(), (size.height - origin.dy).abs());
    return Path()
      ..addOval(Rect.fromCircle(
          center: origin, radius: math.sqrt(dx * dx + dy * dy) * progress));
  }

  @override
  bool shouldReclip(_CareRevealClipper old) =>
      old.origin != origin || old.progress != progress;
}
