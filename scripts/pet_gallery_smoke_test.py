"""Five-photo pet galleries, legacy cover compatibility and household isolation."""
import base64
import struct
import zlib
from smoke_test import call, session, tokens


def png(red):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    return base64.b64encode(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 1, 1, 8, 2, 0, 0, 0))
                            + chunk(b'IDAT', zlib.compress(bytes([0, red, 80, 50]))) + chunk(b'IEND', b'')).decode()


try:
    owner, outsider, member = session(), session(), session()
    photos = [png(n * 40) for n in range(5)]
    body = {'name': 'Gallery test', 'species': 'cat', 'biography': 'Five moments.', 'birthDate': '2020-01-01', 'photos': photos}
    pet_id = call('POST', '/pets', owner, body, 201)['id']
    path = '/pets/' + pet_id

    def profile(token=owner):
        return next(p for p in call('GET', '/dashboard', token)['pets'] if p['id'] == pet_id)

    saved = profile()
    assert saved['photos'] == photos and saved['photoData'] == photos[0]
    for invalid in [photos + [photos[0]], ['!bad-base64'], [''], ['a' * 1500001]]:
        call('PATCH', path, owner, {**body, 'name': 'Should roll back', 'photos': invalid}, 400)
        assert profile() == saved
        call('POST', '/pets', owner, {**body, 'photos': invalid}, 400)
    call('PATCH', path, outsider, body, 404)
    assert call('GET', '/dashboard', outsider)['pets'] == []
    code = call('POST', '/invites', owner)['code']
    call('POST', '/join', member, {'code': code})
    assert profile(member)['photos'] == photos
    reordered = [photos[4], photos[0], photos[2]]
    call('PATCH', path, member, {**body, 'photos': reordered})
    assert profile()['photos'] == reordered and profile()['photoData'] == photos[4]
    assert profile()['createdAt'] == saved['createdAt']
    legacy = {'name': 'Older client', 'species': 'cat', 'photoData': photos[1]}
    call('PATCH', path, owner, legacy)
    assert profile()['photos'] == [photos[1], photos[0], photos[2]]
    call('PATCH', path, owner, {'name': 'Text only update', 'species': 'cat'})
    assert len(profile()['photos']) == 3
    call('PATCH', path, owner, {**body, 'photos': [], 'photoData': photos[0]})
    assert profile()['photos'] == [] and profile()['photoData'] is None
    legacy_id = call('POST', '/pets', owner, legacy, 201)['id']
    legacy_pet = next(p for p in call('GET', '/dashboard', owner)['pets'] if p['id'] == legacy_id)
    assert legacy_pet['photos'] == [photos[1]]
    call('PATCH', path, owner, body)
    call('DELETE', path, owner, expected=204)
    assert all(p['id'] != pet_id for p in call('GET', '/dashboard', member)['pets'])
    print('PASS: five-photo limit, ordered roundtrip, cover selection, rollback, shared access, isolation, legacy preservation, clearing and deletion.')
finally:
    for token in tokens:
        call('DELETE', '/account', token, expected=204)
