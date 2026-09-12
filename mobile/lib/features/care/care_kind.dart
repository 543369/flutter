import 'package:flutter/material.dart';

enum CareKind {
  feeding('FEEDING', '喂食', 'Feeding', 'petcare_food_bowl.png'),
  deworming('DEWORMING', '驱虫', 'Deworming', 'care_deworming.jpg'),
  vaccine('VACCINE', '疫苗', 'Vaccination', 'care_vaccine.jpg'),
  walk('WALK', '散步', 'Walking', 'care_walk.jpg'),
  grooming('GROOMING', '洗护', 'Grooming', 'care_grooming.jpg'),
  custom('CUSTOM', '自定义', 'Custom', 'care_custom.jpg');

  const CareKind(this.code, this.chinese, this.english, this.file);
  final String code, chinese, english, file;
  String label(bool zh) => zh ? chinese : english;
  String get asset => 'assets/images/$file';

  static CareKind of(Map<String, dynamic> item) =>
      values.where((kind) => kind.code == item['careType']).firstOrNull ??
      custom;

  Widget picture({double size = 64}) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
      );
}
