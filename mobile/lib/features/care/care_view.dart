import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import 'care_actions.dart';

extension CareView on CareHomeState {
  List<Map<String, dynamic>> get history => (data?['history'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();

  List<Map<String, dynamic>> get plans => (data?['plans'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();

  String _weekday() {
    const cn = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const en = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return (zh ? cn : en)[DateTime.now().weekday - 1];
  }

  String _time(Map<String, dynamic> task) {
    final date = DateTime.parse(task['dueAt'] as String).toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _heroImage(Map<String, dynamic>? pet) {
    final encoded = pet?['photoData'];
    if (encoded is String && encoded.isNotEmpty) {
      try {
        return Image.memory(base64Decode(encoded),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/petcare_shiba_hero.png',
                fit: BoxFit.cover));
      } catch (_) {}
    }
    return Image.asset('assets/images/petcare_shiba_hero.png',
        fit: BoxFit.cover);
  }

  Widget _petSelector(Map<String, dynamic>? pet, String name) =>
      PopupMenuButton<String>(
        tooltip: t('切换宠物', 'Switch pet'),
        initialValue: pet?['id'] as String?,
        onSelected: (id) => updateUi(() {
          selectedPetId = id;
          careFilter = 'pending';
        }),
        itemBuilder: (_) => pets
            .map((item) => PopupMenuItem<String>(
                  value: item['id'] as String,
                  child: Row(children: [
                    Icon(item['species'] == 'cat'
                        ? Icons.cruelty_free_rounded
                        : Icons.pets_rounded),
                    const SizedBox(width: 10),
                    Text(item['name'] as String),
                  ]),
                ))
            .toList(),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(name,
              style: const TextStyle(
                  color: Color(0xff34231e),
                  fontSize: 21,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: const Color(0xfffff1ba).withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 21, color: Color(0xff34231e))),
        ]),
      );

  Widget _hero(int remaining) {
    final pet = selectedPet;
    final name = pet?['name'] as String? ?? t('豆包', 'Doubao');
    final now = DateTime.now();
    return ClipPath(
      clipper: const _HeroWaveClipper(),
      child: SizedBox(
        height: 392,
        child: Stack(fit: StackFit.expand, children: [
          _heroImage(pet),
          Positioned(
            left: 28,
            top: 22,
            right: 22,
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                Text(t('爪伴', 'PetCare'),
                    style: const TextStyle(
                        color: Color(0xff34231e),
                        fontSize: 27,
                        fontWeight: FontWeight.w800)),
                const Positioned(
                    right: -9,
                    top: 1,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Color(0xffd95e32), shape: BoxShape.circle),
                        child: SizedBox(width: 7, height: 7))),
              ]),
              const Spacer(),
              IconButton(
                  tooltip: t('刷新照护安排', 'Refresh care schedule'),
                  onPressed: busy ? null : () => perform(() async {}),
                  icon: const Icon(Icons.notifications_none_rounded,
                      size: 27, color: Color(0xff34231e))),
            ]),
          ),
          Positioned(
            left: 28,
            top: 92,
            right: 174,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_weekday()} · ${now.month}月${now.day}日',
                  style: const TextStyle(
                      color: Color(0xff76645a),
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(t('今天，\n也要好好陪你。', 'Today,\nwe are here for you.'),
                  style: const TextStyle(
                      color: Color(0xff34231e),
                      fontSize: 32,
                      height: 1.16,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
          Positioned(
            left: 28,
            bottom: 58,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _petSelector(pet, name),
              const SizedBox(height: 4),
              Text(
                  pet?['species'] == 'dog'
                      ? t('狗狗', 'Dog')
                      : pet?['species'] == 'cat'
                          ? t('猫咪', 'Cat')
                          : t('宠物', 'Pet'),
                  style:
                      const TextStyle(color: Color(0xff786961), fontSize: 15)),
            ]),
          ),
          Positioned(
            right: 20,
            bottom: 61,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: Color(0xff5b4439)),
                const SizedBox(width: 7),
                Text(t('$remaining 项待照护', '$remaining tasks to do'),
                    style: const TextStyle(
                        color: Color(0xff4a3730),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color(0xffdf6338), shape: BoxShape.circle),
                  child: SizedBox(width: 8, height: 8)),
              SizedBox(width: 8),
              DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color(0xffd9ccb6), shape: BoxShape.circle),
                  child: SizedBox(width: 8, height: 8)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sun() => Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
            color: Color(0xffdc6338), shape: BoxShape.circle),
        child:
            const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 27),
      );

  Widget _nextCare(Map<String, dynamic> task) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _sun(),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    t('接下来，陪${task['petName']}',
                        'Next up with ${task['petName']}'),
                    style: const TextStyle(
                        color: Color(0xff34231e),
                        fontSize: 18,
                        fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: () => updateUi(() => careFilter = 'plans'),
                child: Row(children: [
                  Text(t('全部安排', 'All plans'),
                      style: const TextStyle(color: Color(0xff867871))),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xff867871))
                ])),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_time(task),
                        style: const TextStyle(
                            color: Color(0xff34231e),
                            fontSize: 48,
                            height: .95,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 9),
                    Text(task['title'] as String,
                        style: const TextStyle(
                            color: Color(0xff34231e),
                            fontSize: 21,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(task['planId'] != null
                        ? t('每天 · 还未完成', 'Daily · Not completed')
                        : t('单次 · 还未完成', 'Once · Not completed')),
                  ]),
            ),
            SizedBox(
                width: 164,
                height: 120,
                child: Image.asset('assets/images/petcare_food_bowl.png',
                    fit: BoxFit.cover)),
          ]),
          const SizedBox(height: 17),
          FilledButton.icon(
              onPressed: busy ? null : () => changeCompletion(task, true),
              icon: const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(t('喂好了', 'Mark as done'))),
        ]),
      );

  Widget _emptyNext() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(children: [
          Row(children: [
            _sun(),
            const SizedBox(width: 12),
            Expanded(
                child: Text(t('今天都照顾好啦', 'All cared for today'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: addTask, child: Text(t('+ 安排', '+ Plan care'))),
          ]),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
                color: const Color(0xfffff7ed),
                borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              const Icon(Icons.favorite_outline_rounded,
                  size: 52, color: Color(0xff684739)),
              const SizedBox(height: 10),
              Text(t('还没有新的照护事项', 'No new care tasks'),
                  style: const TextStyle(
                      color: Color(0xff34231e),
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget _taskRow(Map<String, dynamic> task) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : () => changeCompletion(task, true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const Icon(Icons.directions_walk_rounded,
                  color: Color(0xff887d76), size: 30),
              const SizedBox(width: 16),
              Text(_time(task),
                  style:
                      const TextStyle(color: Color(0xff34231e), fontSize: 18)),
              const SizedBox(width: 18),
              Expanded(
                  child: Text(task['title'] as String,
                      style: const TextStyle(
                          color: Color(0xff34231e),
                          fontSize: 18,
                          fontWeight: FontWeight.w700))),
              const Icon(Icons.chevron_right_rounded, color: Color(0xff81756e)),
            ]),
          ),
        ),
      );

  Widget _eventCard(Map<String, dynamic> event, int index) {
    final at = DateTime.parse(event['at'] as String).toLocal();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 12),
      decoration: BoxDecoration(
          color:
              index.isEven ? const Color(0xffffedda) : const Color(0xffe3f0fb),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Color(0xff746963), fontSize: 13)),
        const SizedBox(height: 5),
        Text(event['title'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Color(0xff34231e),
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        Row(children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Color(0xff8a837e)),
          const SizedBox(width: 6),
          Expanded(
              child: Text('${event['petName']} · ${event['actor'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xff746963), fontSize: 13))),
        ]),
      ]),
    );
  }

  Widget _todayHistory(
          List<Map<String, dynamic>> petHistory, int completedCount) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(t('今天的小日常', 'Today at home'),
                    style: const TextStyle(
                        color: Color(0xff34231e),
                        fontSize: 20,
                        fontWeight: FontWeight.w700))),
            TextButton.icon(
                onPressed: () => updateUi(() => careFilter = 'history'),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(t('记录', 'History'))),
          ]),
          const SizedBox(height: 8),
          if (petHistory.isEmpty)
            Container(
              height: 76,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                  color: const Color(0xfffff1e2),
                  borderRadius: BorderRadius.circular(18)),
              child: Text(t('完成照护后，这里会留下家人的记录。',
                  'Family care moments will appear here.')),
            )
          else
            SizedBox(
              height: 112,
              child: Row(children: [
                for (final entry in petHistory.take(2).indexed) ...[
                  Expanded(child: _eventCard(entry.$2, entry.$1)),
                  if (entry.$1 == 0 && petHistory.length > 1)
                    const SizedBox(width: 12),
                ]
              ]),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: () => updateUi(() => careFilter = 'completed'),
                child: Text(
                    t('已完成 $completedCount 件', '$completedCount completed'))),
          ),
        ]),
      );

  Widget _taskTile(Map<String, dynamic> task) => Card(
        child: CheckboxListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          value: task['completed'] as bool,
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.chevron_right_rounded),
          onChanged: busy ? null : (value) => changeCompletion(task, value!),
          title: Text(task['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${_time(task)} · ${task['petName']}'),
        ),
      );

  Widget _alternateView(
      List<Map<String, dynamic>> completed,
      List<Map<String, dynamic>> petHistory,
      List<Map<String, dynamic>> petPlans) {
    final title = careFilter == 'completed'
        ? t('已完成', 'Completed')
        : careFilter == 'history'
            ? t('照护记录', 'Care history')
            : t('重复计划', 'Recurring plans');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
              tooltip: t('返回今天', 'Back to today'),
              onPressed: () => updateUi(() => careFilter = 'pending'),
              icon: const Icon(Icons.arrow_back_rounded)),
          Text(title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        if (careFilter == 'completed') ...[
          if (completed.isEmpty)
            empty(
                t('还没有已完成事项', 'No completed tasks'),
                t('完成照护后会出现在这里。', 'Completed care appears here.'),
                Icons.check_circle_outline_rounded),
          ...completed.map(_taskTile),
        ] else if (careFilter == 'history') ...[
          if (petHistory.isEmpty)
            empty(
                t('还没有照护记录', 'No care history yet'),
                t('家人完成事项后，会在这里留下记录。',
                    'Completed care will appear here with the caregiver.'),
                Icons.history_rounded),
          ...petHistory.indexed.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                    height: 112, child: _eventCard(entry.$2, entry.$1)),
              )),
        ] else ...[
          if (petPlans.isEmpty)
            empty(
                t('还没有重复计划', 'No recurring plans'),
                t('安排照护时选择每天或每周。',
                    'Choose daily or weekly when planning care.'),
                Icons.repeat_rounded),
          ...petPlans.map((plan) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xffffe0c6),
                      child:
                          Icon(Icons.repeat_rounded, color: Color(0xff8d4a2c))),
                  title: Text('${plan['petName']} · ${plan['title']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(plan['frequency'] == 'DAILY'
                      ? t('每天', 'Daily')
                      : t('每周', 'Weekly')),
                ),
              )),
        ],
        const SizedBox(height: 16),
        Card(
          color: const Color(0xfff7f2ec),
          child: SwitchListTile(
            title: Text(t('到时提醒', 'Care reminders'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                t('在这台设备上接收照护提醒', 'Receive care reminders on this device')),
            value: reminders.enabled,
            onChanged: busy ? null : toggleReminders,
          ),
        ),
      ]),
    );
  }

  List<Widget> careView() {
    final pet = selectedPet;
    final petId = pet?['id'];
    final petName = pet?['name'];
    final petTasks = tasks.where((task) => task['petId'] == petId).toList();
    final petHistory = history
        .where((event) =>
            event['petId'] == petId ||
            (event['petId'] == null && event['petName'] == petName))
        .toList();
    final petPlans = plans
        .where((plan) =>
            plan['petId'] == petId ||
            (plan['petId'] == null && plan['petName'] == petName))
        .toList();
    final pending = petTasks.where((v) => v['completed'] != true).toList()
      ..sort((a, b) => DateTime.parse(a['dueAt'] as String)
          .compareTo(DateTime.parse(b['dueAt'] as String)));
    final completed = petTasks.where((v) => v['completed'] == true).toList();
    return [
      _hero(pending.length),
      if (error != null)
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(t('同步失败，当前显示上次的数据。请下拉重试。',
                'Sync failed. Showing the last update. Pull to retry.'))),
      if (careFilter == 'pending') ...[
        if (pending.isEmpty) _emptyNext() else _nextCare(pending.first),
        if (pending.length > 1) _taskRow(pending[1]),
        _todayHistory(petHistory, completed.length),
      ] else
        _alternateView(completed, petHistory, petPlans),
    ];
  }
}

class _HeroWaveClipper extends CustomClipper<Path> {
  const _HeroWaveClipper();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 35)
    ..quadraticBezierTo(
        size.width * .5, size.height + 5, size.width, size.height - 35)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant _HeroWaveClipper oldClipper) => false;
}
