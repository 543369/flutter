import 'package:flutter/material.dart';
import '../subjects/subject_scenarios.dart';

enum CareKind {
  feeding('FEEDING', '喂食', 'Feeding', 'care_feeding_transparent.png'),
  water('WATER', '换水', 'Fresh water', 'care_water_transparent.png'),
  deworming('DEWORMING', '驱虫', 'Deworming', 'care_deworming_transparent.png'),
  vaccine('VACCINE', '疫苗', 'Vaccination', 'care_vaccine_transparent.png'),
  walk('WALK', '散步', 'Walking', 'care_walk_transparent.png'),
  grooming('GROOMING', '洗护', 'Grooming', 'care_grooming_transparent.png'),
  meal('MEAL', '用餐', 'Meal', 'care_custom_transparent.png'),
  drink('DRINK', '喝水', 'Drink water', 'care_water_transparent.png'),
  medication('MEDICATION', '用药', 'Medication', 'care_custom_transparent.png'),
  rehab('REHAB', '康复训练', 'Rehabilitation', 'care_custom_transparent.png'),
  appointment(
      'APPOINTMENT', '复诊', 'Appointment', 'care_custom_transparent.png'),
  daily('DAILY', '日常起居', 'Daily living', 'care_custom_transparent.png'),
  nurture('NURTURE', '喂养', 'Feeding care', 'care_custom_transparent.png'),
  sleep('SLEEP', '睡眠记录', 'Sleep record', 'care_custom_transparent.png'),
  growth('GROWTH', '成长记录', 'Growth record', 'care_custom_transparent.png'),
  pickup('PICKUP', '接送', 'Pick-up / drop-off', 'care_custom_transparent.png'),
  handover('HANDOVER', '照护交接', 'Care handover', 'care_custom_transparent.png'),
  observation('OBSERVATION', '康复观察', 'Recovery observation',
      'care_custom_transparent.png'),
  custom('CUSTOM', '自定义', 'Custom', 'care_custom_transparent.png');

  const CareKind(this.code, this.chinese, this.english, this.file);
  final String code, chinese, english, file;
  String label(bool zh) => zh ? chinese : english;
  String get asset => 'assets/images/$file';

  static List<CareKind> forSubject(Map<String, dynamic>? subject) {
    if (subject?['subjectType'] != 'HUMAN') {
      return [feeding, water, deworming, vaccine, walk, grooming, custom];
    }
    final scenarios = scenariosFor(subject).toSet();
    final kinds = <CareKind>{};
    if (scenarios.contains('DAILY')) {
      kinds.addAll(subject?['lifeStage'] == 'CHILD'
          ? [nurture, sleep, growth, pickup]
          : [meal, drink, daily]);
      kinds.add(handover);
    }
    kinds.addAll([medication, appointment]);
    if (scenarios.contains('RECOVERY')) {
      kinds.addAll([observation, rehab, handover]);
    }
    kinds.add(custom);
    return kinds.toList();
  }

  static CareKind of(Map<String, dynamic> item) {
    // Older water tasks were stored as CUSTOM before WATER was available.
    final title = (item['title'] as String? ?? '').trim().toLowerCase();
    if ((item['careType'] == 'CUSTOM' || item['careType'] == null) &&
        const {'换水', 'fresh water', 'change water'}.contains(title)) {
      return water;
    }
    return values.where((kind) => kind.code == item['careType']).firstOrNull ??
        custom;
  }

  Widget picture({double size = 64}) => [
        meal,
        drink,
        medication,
        rehab,
        appointment,
        daily,
        nurture,
        sleep,
        growth,
        pickup,
        handover,
        observation
      ].contains(this)
          ? SizedBox(
              width: size,
              height: size,
              child: Icon(
                  switch (this) {
                    CareKind.meal => Icons.restaurant,
                    CareKind.drink => Icons.water_drop_outlined,
                    CareKind.medication => Icons.medication_outlined,
                    CareKind.rehab => Icons.accessibility_new,
                    CareKind.appointment => Icons.event_available,
                    CareKind.nurture => Icons.child_care,
                    CareKind.sleep => Icons.bedtime_outlined,
                    CareKind.growth => Icons.straighten,
                    CareKind.pickup => Icons.directions_car_outlined,
                    CareKind.handover => Icons.swap_horiz,
                    CareKind.observation => Icons.assignment_outlined,
                    _ => Icons.volunteer_activism_outlined
                  },
                  size: size * .65,
                  color: const Color(0xff694536)))
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(asset,
                  width: size, height: size, fit: BoxFit.contain),
            );
}
