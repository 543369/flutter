import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/api.dart';

class MediaApi extends CareApi {
  int version = 1, photoCalls = 0;
  bool deleted = false;
  Completer<void>? photoGate;
  bool failPhotos = false;
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
      await photoGate?.future;
      if (failPhotos) throw TimeoutException('photos');
      return {
        'photoRevision': version,
        'photos': version == 1 ? ['AA=='] : []
      };
    }
    throw StateError(path);
  }
}

Future<Map<String, dynamic>> withPhotos(MediaApi api) async {
  final result = await api.dashboard();
  for (final pet in result['pets'] as List) {
    if (pet['photosPending'] == true) {
      pet.addAll(await api.loadPetPhotos(Map<String, dynamic>.from(pet)));
    }
  }
  return result;
}

void main() {
  test('dashboard is usable while photos stall, fail, and retry separately', () async {
    final api = MediaApi()..token = 'one';
    final dashboard = await api.dashboard();
    expect(api.photoCalls, 0);
    final pet = Map<String, dynamic>.from((dashboard['pets'] as List).single);
    api.photoGate = Completer<void>();
    api.failPhotos = true;
    final download = api.loadPetPhotos(pet);
    final failure = expectLater(download, throwsA(isA<TimeoutException>()));
    expect((await api.dashboard())['tasks'], isEmpty);
    api.photoGate!.complete();
    await failure;
    expect((await api.dashboard())['pets'], isNotEmpty);
    api.failPhotos = false;
    await api.loadPetPhotos(pet);
    expect(((await api.dashboard())['pets'] as List).single['photos'], ['AA==']);
    expect(api.photoCalls, 2);
  });

  test(
      'unchanged galleries reuse cache; edits, deletion and sessions invalidate it',
      () async {
    final api = MediaApi()..token = 'one';
    expect(
        ((await withPhotos(api))['pets'] as List).single['photos'], ['AA==']);
    await withPhotos(api);
    expect(api.photoCalls, 1);
    api.version = 2;
    expect(((await withPhotos(api))['pets'] as List).single['photos'], isEmpty);
    expect(api.photoCalls, 2);
    api.deleted = true;
    await withPhotos(api);
    api.deleted = false;
    await withPhotos(api);
    expect(api.photoCalls, 3);
    api.token = 'two';
    await withPhotos(api);
    expect(api.photoCalls, 4);
  });
}
