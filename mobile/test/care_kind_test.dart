import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/features/care/care_kind.dart';

void main() {
  test('water type and legacy water titles use water artwork', () {
    expect(
        CareKind.of({'careType': 'WATER', 'title': '给豆包添水'}), CareKind.water);
    expect(CareKind.of({'careType': 'CUSTOM', 'title': '换水'}), CareKind.water);
    expect(CareKind.of({'careType': 'CUSTOM', 'title': '换水后观察食欲'}),
        CareKind.custom);
    expect(
        CareKind.of({'careType': 'FEEDING', 'title': '换水'}), CareKind.feeding);
    expect(CareKind.water.asset, 'assets/images/care_water_transparent.png');
  });

  test('stage and stackable scenarios narrow templates without changing pets',
      () {
    List<CareKind> kinds(String stage, List<String> scenes) =>
        CareKind.forSubject({
          'subjectType': 'HUMAN',
          'lifeStage': stage,
          'careScenarios': scenes
        });
    final child = kinds('CHILD', ['DAILY']);
    expect(
        child,
        containsAll([
          CareKind.nurture,
          CareKind.sleep,
          CareKind.growth,
          CareKind.pickup
        ]));
    expect(child, isNot(contains(CareKind.rehab)));
    expect(child, isNot(contains(CareKind.drink)));
    final mixed = kinds('CHILD', ['DAILY', 'RECOVERY']);
    expect(mixed,
        containsAll([CareKind.pickup, CareKind.observation, CareKind.rehab]));
    expect(mixed.toSet().length, mixed.length);
    final elder = kinds('ELDER', ['DAILY']);
    expect(
        elder, containsAll([CareKind.meal, CareKind.drink, CareKind.handover]));
    expect(elder, isNot(contains(CareKind.pickup)));
    final recovery = kinds('ELDER', ['RECOVERY']);
    expect(recovery, contains(CareKind.rehab));
    expect(recovery, isNot(contains(CareKind.meal)));
    expect(
        CareKind.forSubject({
          'subjectType': 'PET',
          'lifeStage': 'CHILD',
          'careScenarios': ['RECOVERY']
        }),
        contains(CareKind.deworming));
  });
}
