import 'package:flutter/material.dart';

enum CareKind {
  feeding('FEEDING', '喂食', 'Feeding', 'care_feeding_transparent.png'),
  water('WATER', '换水', 'Fresh water', 'care_water_transparent.png'),
  deworming('DEWORMING', '驱虫', 'Deworming', 'care_deworming_transparent.png'),
  vaccine('VACCINE', '疫苗', 'Vaccination', 'care_vaccine_transparent.png'),
  walk('WALK', '散步', 'Walking', 'care_walk_transparent.png'),
  grooming('GROOMING', '洗护', 'Grooming', 'care_grooming_transparent.png'),
  custom('CUSTOM', '自定义', 'Custom', 'care_custom_transparent.png');

  const CareKind(this.code, this.chinese, this.english, this.file);
  final String code, chinese, english, file;
  String label(bool zh) => zh ? chinese : english;
  String get asset => 'assets/images/$file';

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

  Widget picture({double size = 64}) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
      );
}
