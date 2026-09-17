import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/features/care/care_kind.dart';

void main() {
  test('water type and legacy water titles use water artwork', () {
    expect(CareKind.of({'careType': 'WATER', 'title': '给豆包添水'}), CareKind.water);
    expect(CareKind.of({'careType': 'CUSTOM', 'title': '换水'}), CareKind.water);
    expect(CareKind.of({'careType': 'CUSTOM', 'title': '换水后观察食欲'}), CareKind.custom);
    expect(CareKind.of({'careType': 'FEEDING', 'title': '换水'}), CareKind.feeding);
    expect(CareKind.water.asset, 'assets/images/care_water_transparent.png');
  });
}
