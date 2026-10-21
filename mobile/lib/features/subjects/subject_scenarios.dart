const lifeStages = <String, (String, String)>{
  'ELDER': ('长辈', 'Older adult'),
  'CHILD': ('儿童', 'Child'),
  'OTHER': ('其他／未指定', 'Other / unspecified'),
};
const careScenarios = <String, (String, String)>{
  'DAILY': ('日常照护', 'Daily care'),
  'RECOVERY': ('术后／康复照护', 'Recovery care'),
};
List<String> scenariosFor(Map<String, dynamic>? subject) {
  final raw = subject?['careScenarios'];
  // Older cached profiles used the full human template set.
  return raw is List ? raw.whereType<String>().toList() : ['DAILY', 'RECOVERY'];
}

String stageLabel(String? stage, bool zh) {
  final label = lifeStages[stage] ?? lifeStages['OTHER']!;
  return zh ? label.$1 : label.$2;
}

String scenarioLabel(String code, bool zh) {
  final label = careScenarios[code];
  return label == null
      ? code
      : zh
          ? label.$1
          : label.$2;
}
