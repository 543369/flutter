import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import 'care_actions.dart';
import 'care_pages.dart';
import 'care_kind.dart';
import '../pets/pet_photo_carousel.dart';
import '../../core/widgets/brand_motion.dart';

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

  Widget _petSelector(Map<String, dynamic>? pet, String name) =>
      PopupMenuButton<String>(
        clipBehavior: Clip.antiAlias,
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
                    const SizedBox(width: AppSpacing.inline),
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
          const SizedBox(width: AppSpacing.inline),
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
        child: PetPhotoCarousel(
            pet: pet ?? {'species': 'dog'},
            indicatorBottom: 12,
            overlay: [
              Positioned(
                left: 28,
                top: 22,
                right: 22,
                child: Row(children: [
                  const DefaultTextStyle(
                      style: TextStyle(
                          color: Color(0xff34231e),
                          fontSize: 24,
                          fontWeight: FontWeight.w700),
                      child: BrandWordmark()),
                  const Spacer(),
                  IconButton(
                      tooltip: t('提醒设置', 'Reminder settings'),
                      onPressed: openReminderSettings,
                      icon: const Icon(Icons.notifications_none_rounded,
                          size: 27, color: Color(0xff34231e))),
                ]),
              ),
              Positioned(
                left: 28,
                top: 92,
                right: 174,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_weekday()} · ${now.month}月${now.day}日',
                          style: const TextStyle(
                              color: Color(0xff76645a),
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.item),
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _petSelector(pet, name),
                      const SizedBox(height: AppSpacing.tight),
                      Text(
                          pet?['species'] == 'dog'
                              ? t('狗狗', 'Dog')
                              : pet?['species'] == 'cat'
                                  ? t('猫咪', 'Cat')
                                  : t('宠物', 'Pet'),
                          style: const TextStyle(
                              color: Color(0xff786961), fontSize: 15)),
                    ]),
              ),
              Positioned(
                right: 20,
                bottom: 61,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 20, color: Color(0xff5b4439)),
                    const SizedBox(width: AppSpacing.inline),
                    Text(t('$remaining 项待照护', '$remaining tasks to do'),
                        style: const TextStyle(
                            color: Color(0xff4a3730),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
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
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.content, AppSpacing.page, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _sun(),
            const SizedBox(width: AppSpacing.item),
            Expanded(
                child: Text(
                    t('接下来，陪${task['petName']}',
                        'Next up with ${task['petName']}'),
                    style: const TextStyle(
                        color: Color(0xff34231e),
                        fontSize: 18,
                        fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: openSchedules,
                child: Row(children: [
                  Text(t('全部安排', 'All plans'),
                      style: const TextStyle(color: Color(0xff867871))),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xff867871))
                ])),
          ]),
          const SizedBox(height: AppSpacing.content),
          Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: const ValueKey('next-care-details'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => openTaskDetails(task),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                              const SizedBox(height: AppSpacing.inline),
                              Text(task['title'] as String,
                                  style: const TextStyle(
                                      color: Color(0xff34231e),
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: AppSpacing.inline),
                              Text(
                                  '${frequencyLabel(planFor(task))} · ${t('还未完成', 'Not completed')}'),
                            ]),
                      ),
                      const SizedBox(width: AppSpacing.inline),
                      Flexible(
                        child: SizedBox(
                          height: 120,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => const RadialGradient(
                              colors: [
                                Colors.white,
                                Colors.white,
                                Colors.transparent
                              ],
                              stops: [0, .65, 1],
                              radius: .72,
                            ).createShader(bounds),
                            child: Image.asset(CareKind.of(task).asset,
                                fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.content),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: busy ? null : () => changeCompletion(task, true),
                  icon: const Icon(Icons.check_circle_rounded, size: 22),
                  label: Text(CareKind.of(task) == CareKind.feeding
                      ? t('喂好了', 'Mark as done')
                      : t('完成照护', 'Mark as done')))),
        ]),
      );

  Widget _emptyNext() => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.content, AppSpacing.page, 0),
        child: Column(children: [
          Row(children: [
            _sun(),
            const SizedBox(width: AppSpacing.item),
            Expanded(
                child: Text(t('今天都照顾好啦', 'All cared for today'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: openSchedules, child: Text(t('全部安排', 'All plans'))),
          ]),
          const SizedBox(height: AppSpacing.content),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
                color: const Color(0xfffff7ed),
                borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              const Icon(Icons.favorite_outline_rounded,
                  size: 52, color: Color(0xff684739)),
              const SizedBox(height: AppSpacing.inline),
              Text(t('还没有新的照护事项', 'No new care tasks'),
                  style: const TextStyle(
                      color: Color(0xff34231e),
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              TextButton.icon(
                  onPressed: busy ? null : addTask,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t('新建安排', 'New plan'))),
            ]),
          ),
        ]),
      );

  Widget _taskRow(Map<String, dynamic> task) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.item, AppSpacing.page, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openTaskDetails(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.content, vertical: AppSpacing.item),
            child: Row(children: [
              CareKind.of(task).picture(size: 38),
              const SizedBox(width: AppSpacing.content),
              Text(_time(task),
                  style:
                      const TextStyle(color: Color(0xff34231e), fontSize: 18)),
              const SizedBox(width: AppSpacing.content),
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
    return Material(
      color: index.isEven ? const Color(0xffffedda) : const Color(0xffe3f0fb),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openRecordDetails(event),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.content,
              AppSpacing.item, AppSpacing.content, AppSpacing.item),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Color(0xff746963), fontSize: 13)),
            const SizedBox(height: AppSpacing.tight),
            Text(event['title'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xff34231e),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Row(children: [
              Icon(
                  event['action'] == 'REOPENED'
                      ? Icons.undo_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xff8a837e)),
              const SizedBox(width: AppSpacing.inline),
              Expanded(
                  child: Text('${event['petName']} · ${event['actor'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xff746963), fontSize: 13))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _todayHistory(
          List<Map<String, dynamic>> petHistory, int completedCount) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.section,
            AppSpacing.page, AppSpacing.inline),
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
                icon: const Icon(Icons.history_rounded, size: 20),
                label: Text(t('记录', 'History'))),
          ]),
          const SizedBox(height: AppSpacing.inline),
          if (petHistory.isEmpty)
            Container(
              height: 76,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.content),
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
                    const SizedBox(width: AppSpacing.item),
                ]
              ]),
            ),
          const SizedBox(height: AppSpacing.inline),
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
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.content, vertical: AppSpacing.tight),
          leading: Checkbox(
            value: task['completed'] == true,
            onChanged: busy ? null : (value) => changeCompletion(task, value!),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openTaskDetails(task),
          title: Text(task['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${_time(task)} · ${task['petName']}'),
        ),
      );

  Widget _alternateView(List<Map<String, dynamic>> completed,
      List<Map<String, dynamic>> petHistory) {
    final title = careFilter == 'completed'
        ? t('已完成', 'Completed')
        : t('照护记录', 'Care history');
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.section,
          AppSpacing.page, AppSpacing.section),
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
        const SizedBox(height: AppSpacing.item),
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
        ],
      ]),
    );
  }

  Widget careScrollView() {
    final sections = careView();
    final pet = selectedPet;
    return CustomScrollView(
      key: const PageStorageKey('home-tab-0'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _CareHeroHeader(
            expanded: sections.first,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            compact: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(children: [
                Expanded(
                    child: _petSelector(
                        pet, pet?['name'] as String? ?? t('豆包', 'Doubao'))),
                IconButton(
                  tooltip: t('提醒设置', 'Reminder settings'),
                  onPressed: openReminderSettings,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          sliver: SliverList.list(children: sections.skip(1).toList()),
        ),
      ],
    );
  }

  List<Widget> careView() {
    final pet = selectedPet;
    final petId = pet?['id'];
    final petName = pet?['name'];
    final petTasks = tasks.where((task) => task['petId'] == petId).toList();
    final petHistory = history
        .where(
          (event) =>
              event['petId'] == petId ||
              (event['petId'] == null && event['petName'] == petName),
        )
        .toList();
    final pending = petTasks.where((v) => v['completed'] != true).toList()
      ..sort(
        (a, b) => DateTime.parse(
          a['dueAt'] as String,
        ).compareTo(DateTime.parse(b['dueAt'] as String)),
      );
    final completed = petTasks.where((v) => v['completed'] == true).toList();
    return [
      GentleSwitch(
        child: KeyedSubtree(key: ValueKey(petId), child: _hero(pending.length)),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            t(
              '同步失败，当前显示上次的数据。请下拉重试。',
              'Sync failed. Showing the last update. Pull to retry.',
            ),
          ),
        ),
      AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: GentleSwitch(
          child: Column(
            key: ValueKey('$petId-$careFilter-${pending.firstOrNull?['id']}'),
            children: [
              if (careFilter == 'pending') ...[
                if (pending.isEmpty) _emptyNext() else _nextCare(pending.first),
                if (pending.length > 1) _taskRow(pending[1]),
                _todayHistory(petHistory, completed.length),
              ] else
                _alternateView(completed, petHistory),
            ],
          ),
        ),
      ),
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

/// The header follows the scroll position directly, so reversing a gesture
/// expands it without a second animation or a jump in the care content.
class _CareHeroHeader extends SliverPersistentHeaderDelegate {
  _CareHeroHeader(
      {required this.expanded,
      required this.compact,
      required this.reduceMotion});

  final Widget expanded;
  final Widget compact;
  final bool reduceMotion;

  @override
  double get minExtent => 72;
  @override
  double get maxExtent => 392;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1 - progress / .75).clamp(0.0, 1.0);
    final compactOpacity = ((progress - .65) / .35).clamp(0.0, 1.0);
    return ClipRect(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(fit: StackFit.expand, children: [
          Positioned(
            top: -shrinkOffset * (reduceMotion ? 1 : .3),
            left: 0,
            right: 0,
            height: maxExtent,
            child: IgnorePointer(
              ignoring: progress > .5,
              child: ExcludeSemantics(
                excluding: progress > .5,
                child: Opacity(opacity: expandedOpacity, child: expanded),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: minExtent,
            child: IgnorePointer(
              ignoring: progress <= .65,
              child: ExcludeSemantics(
                excluding: progress <= .65,
                child: Opacity(opacity: compactOpacity, child: compact),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CareHeroHeader oldDelegate) =>
      expanded != oldDelegate.expanded ||
      compact != oldDelegate.compact ||
      reduceMotion != oldDelegate.reduceMotion;
}
