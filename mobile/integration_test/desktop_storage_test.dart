import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petcare/core/network/care_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('desktop can reach API and securely persist credentials', (tester) async {
    final api = CareApi();
    expect((await api.request('GET', '/health'))['status'], 'ok');
    final key = 'storage-probe-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await api.storage.write(key: key, value: 'temporary-test-value');
      expect(await api.storage.read(key: key), 'temporary-test-value');
    } finally {
      await api.storage.delete(key: key);
    }
  });
}
