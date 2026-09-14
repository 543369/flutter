"""Run against a disposable local API configured with a 400-byte preview quota."""
import base64
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
import json
import urllib.request
import urllib.error
from smoke_test import call, session, tokens, BASE

PHOTO = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII='
photo_bytes = len(base64.b64decode(PHOTO))

try:
    owner, member, outsider = session(), session(), session()
    status = call('GET', '/benefits', owner)
    assert status['tier'] == 'PREVIEW' and status['limitBytes'] == 400
    assert status['usedBytes'] == 0 and status['billingEnabled'] is False
    profile = {'name': 'Benefits test', 'species': 'cat', 'photos': [PHOTO] * 3}
    pet = call('POST', '/pets', owner, profile, 201)['id']
    assert call('GET', '/benefits', owner)['usedBytes'] == photo_bytes * 3
    path = f'/pets/{pet}/memories'
    body = {'title': 'Sunshine', 'story': 'A happy day.', 'happenedOn': date.today().isoformat(), 'photos': [PHOTO]}
    memory = call('POST', path, owner, body, 201)['id']
    call('PATCH', f'{path}/{memory}', owner, {**body, 'story': 'Should roll back', 'photos': [PHOTO] * 3}, 413)
    assert call('GET', f'{path}/{memory}', owner)['story'] == body['story']
    call('PATCH', f'/pets/{pet}', owner, {**profile, 'photos': [PHOTO] * 5}, 413)
    assert call('GET', '/benefits', owner)['photoCount'] == 4
    code = call('POST', '/invites', owner)['code']
    call('POST', '/join', member, {'code': code})
    assert call('GET', '/benefits', owner) == call('GET', '/benefits', member)
    assert call('GET', '/benefits', outsider)['usedBytes'] == 0

    def concurrent_upload(token):
        request = urllib.request.Request(BASE + path, data=json.dumps(body).encode(), method='POST',
                    headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.status
        except urllib.error.HTTPError as error:
            return error.code

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(concurrent_upload, [owner, member]))
    assert sorted(results) == [201, 413], results
    assert call('GET', '/benefits', owner)['usedBytes'] == photo_bytes * 5
    # Text-only records remain writable when no photo growth is possible.
    for n in range(4):
        call('POST', path, owner, {**body, 'title': f'Text {n}', 'photos': []}, 201)
    export = call('GET', f'/benefits/memories/{pet}', member)
    assert len(export['items']) == 3 and export['hasMore']
    second = call('GET', f'/benefits/memories/{pet}?offset=3', owner)
    assert len(second['items']) == 3 and not second['hasMore']
    assert sum(len(m['photos']) for m in export['items'] + second['items']) == 2
    call('GET', f'/benefits/memories/{pet}', outsider, expected=404)
    call('GET', f'/benefits/memories/{pet}?offset=-1', owner, expected=400)
    year = datetime.now(timezone.utc).year
    task = call('POST', '/tasks', owner, {'petId': pet, 'title': 'Meal', 'careType': 'FEEDING',
          'dueAt': datetime.now(timezone.utc).isoformat(), 'frequency': 'NONE'}, 201)['id']
    for completed in [True, False, True]:
        call('PATCH', f'/tasks/{task}', owner, {'completed': completed})
    report = call('GET', f'/benefits/annual?year={year}&zoneId=Asia%2FShanghai', owner)
    assert report['careCount'] == 1 and sum(report['monthlyCare']) == 1
    assert report['memoryCount'] == 6 and report['careTypes']['FEEDING'] == 1
    assert report['pets'][0]['careCount'] == 1 and report['activeDays'] == 1
    call('PATCH', f'/tasks/{task}', owner, {'completed': False})
    assert call('GET', f'/benefits/annual?year={year}', owner)['careCount'] == 0
    assert call('GET', f'/benefits/annual?year={year-1}', owner)['memoryCount'] == 0
    assert call('GET', f'/benefits/annual?year={year}', outsider)['pets'] == []
    call('GET', f'/benefits/annual?year={year+1}', owner, expected=400)
    call('GET', f'/benefits/annual?year={year}&zoneId=invalid', owner, expected=400)
    call('DELETE', f'{path}/{memory}', owner, expected=204)
    assert call('GET', '/benefits', owner)['usedBytes'] == photo_bytes * 4
    call('DELETE', f'/pets/{pet}', owner, expected=204)
    assert call('GET', '/benefits', member)['usedBytes'] == 0
    print('PASS: exact storage accounting, shared quota, concurrent limit, rollback, export pagination, isolation, annual deduplication and space reclamation.')
finally:
    for token in tokens:
        call('DELETE', '/account', token, expected=204)
