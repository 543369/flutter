"""Memoir API integration checks; all disposable households are cleaned up."""
from datetime import date, timedelta
from smoke_test import call, session, tokens

PHOTO = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII='

try:
    owner, member, outsider = session(), session(), session()
    pet = call('POST', '/pets', owner, {'name': 'Memory test', 'species': 'cat'}, 201)['id']
    other = call('POST', '/pets', owner, {'name': 'Other pet', 'species': 'dog'}, 201)['id']
    path = f'/pets/{pet}/memories'
    payload = {'title': 'First hello', 'story': 'A sunny afternoon together.',
               'happenedOn': '2026-01-01', 'photos': [PHOTO, PHOTO]}
    memory = call('POST', path, owner, payload, 201)['id']
    detail = call('GET', f'{path}/{memory}', owner)
    assert detail['photos'] == payload['photos'] and detail['createdAt']
    page = call('GET', path, owner)
    assert page['total'] == 1 and page['items'][0]['photoCount'] == 2
    assert page['items'][0]['coverData'] == PHOTO and not page['hasMore']
    assert next(p for p in call('GET', '/dashboard', owner)['pets'] if p['id'] == pet)['memoryCount'] == 1
    for method in ['GET', 'PATCH', 'DELETE']:
        call(method, f'{path}/{memory}', outsider,
             payload if method == 'PATCH' else None, 404)
        call(method, f'/pets/{other}/memories/{memory}', owner,
             payload if method == 'PATCH' else None, 404)
    call('GET', path, outsider, expected=404)
    call('POST', path, outsider, payload, 404)
    call('GET', path + '?offset=-1', owner, expected=400)
    for invalid in [{'title': ' '}, {'story': 'x' * 5001}, {'photos': [PHOTO] * 7},
                    {'photos': ['!bad-base64']}, {'photos': None},
                    {'happenedOn': (date.today() + timedelta(days=2)).isoformat()}]:
        call('POST', path, owner, {**payload, **invalid}, 400)
    # An invalid image replacement must roll back both the text and old photos.
    call('PATCH', f'{path}/{memory}', owner,
         {**payload, 'title': 'Should roll back', 'photos': [PHOTO, '!bad']}, 400)
    assert call('GET', f'{path}/{memory}', owner) == detail
    code = call('POST', '/invites', owner)['code']
    call('POST', '/join', member, {'code': code})
    assert call('GET', f'{path}/{memory}', member)['photos'] == payload['photos']
    board = call('GET', '/dashboard', member)
    assert len(board['memberProfiles']) == 2
    assert sum(p['isMe'] for p in board['memberProfiles']) == 1
    call('PATCH', f'{path}/{memory}', member, {**payload, 'title': 'Our shared story', 'photos': []})
    edited = call('GET', f'{path}/{memory}', owner)
    assert edited['createdAt'] == detail['createdAt'] and edited['author'] == detail['author']
    assert edited['photos'] == [] and edited['title'] == 'Our shared story'
    ids = {memory}
    for n in range(13):
        ids.add(call('POST', path, owner, {**payload, 'title': f'Moment {n}', 'photos': []}, 201)['id'])
    first = call('GET', path, owner)
    second = call('GET', path + '?offset=12', owner)
    assert first['total'] == 14 and len(first['items']) == 12 and first['hasMore']
    assert len(second['items']) == 2 and not second['hasMore']
    assert {m['id'] for m in first['items'] + second['items']} == ids
    call('DELETE', f'{path}/{memory}', member, expected=204)
    call('GET', f'{path}/{memory}', owner, expected=404)
    # Deleting a pet with a photographed story exercises the FK cascade.
    call('POST', path, owner, payload, 201)
    call('DELETE', f'/pets/{pet}', owner, expected=204)
    call('GET', path, member, expected=404)
    assert all(p['id'] != pet for p in call('GET', '/dashboard', owner)['pets'])
    print('PASS: photo roundtrip, validation and rollback, pagination, shared editing, household isolation, timestamps and pet deletion cascade.')
finally:
    for token in tokens:
        call('DELETE', '/account', token, expected=204)
