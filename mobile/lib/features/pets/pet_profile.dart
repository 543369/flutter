String petBirthLabel(String? value) {
  final date = DateTime.tryParse(value ?? '');
  return date == null ? '' : '${date.year}/${date.month}/${date.day}';
}

String petAgeLabel(String? value, DateTime now, {required bool chinese}) {
  final birth = DateTime.tryParse(value ?? '');
  if (birth == null) return chinese ? '年龄未填写' : 'Age not set';
  final today = DateTime.utc(now.year, now.month, now.day);
  final birthday = DateTime.utc(birth.year, birth.month, birth.day);
  if (birthday.isAfter(today)) return chinese ? '年龄未填写' : 'Age not set';
  var months = (now.year - birth.year) * 12 + now.month - birth.month;
  final lastDay = DateTime.utc(now.year, now.month + 1, 0).day;
  final anniversaryDay = birth.day > lastDay ? lastDay : birth.day;
  if (now.day < anniversaryDay) months--;
  if (months < 1) {
    final days = today.difference(birthday).inDays;
    return chinese ? '$days 天' : '$days days';
  }
  final years = months ~/ 12;
  final remaining = months % 12;
  if (years == 0) return chinese ? '$months 个月' : '$months months';
  if (remaining == 0) return chinese ? '$years 岁' : '$years years';
  return chinese ? '$years 岁 $remaining 个月' : '$years years $remaining months';
}
