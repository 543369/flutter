import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';

class MediaApi extends CareApi {
  int version = 1, photoCalls = 0;
  bool deleted = false;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path == '/dashboard?compact=true') {
      return {
        'pets': deleted
            ? []
            : [
                {'id': 'pet', 'photoRevision': version}
              ],
        'tasks': []
      };
    }
    if (path == '/pets/pet/photos') {
      photoCalls++;
      return {
        'photoRevision': version,
        'photos': version == 1 ? ['AA=='] : []
      };
    }
    throw StateError(path);
  }
}

void main() {
  test(
      'unchanged galleries reuse cache; edits, deletion and sessions invalidate it',
      () async {
    final api = MediaApi()..token = 'one';
    expect(
        ((await api.dashboard())['pets'] as List).single['photos'], ['AA==']);
    await api.dashboard();
    expect(api.photoCalls, 1);
    api.version = 2;
    expect(((await api.dashboard())['pets'] as List).single['photos'], isEmpty);
    expect(api.photoCalls, 2);
    api.deleted = true;
    await api.dashboard();
    api.deleted = false;
    await api.dashboard();
    expect(api.photoCalls, 3);
    api.token = 'two';
    await api.dashboard();
    expect(api.photoCalls, 4);
  });
}
