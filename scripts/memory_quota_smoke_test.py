"""Local API with preview disabled. Isolated accounts are removed after testing."""
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from smoke_test import call, session

owner = session()
member = None
try:
    member = session()
    code = call('POST', '/invites', owner)['code']
    call('POST', '/join', member, {'code': code})
    assert call('GET', '/benefits', owner)['tier'] == 'FREE'
    pets = [call('POST', '/pets', owner, {'name': 'Quota test', 'species': 'cat'}, 201)['id'] for _ in range(2)]
    body = {'title': 'Story', 'story': 'Shared household allowance', 'happenedOn': date.today().isoformat(), 'photos': []}
    paths = [f'/pets/{p}/memories' for p in pets]
    ids = [call('POST', paths[i % 2], owner, body, 201)['id'] for i in range(9)]
    call('POST', paths[0], owner, {**body, 'photos': ['invalid!']}, 400)
    assert call('GET', '/benefits', owner)['memoryCreatedCount'] == 9
    def attempt(args):
        token, path = args
        import json, urllib.request, urllib.error
        from smoke_test import BASE
        req = urllib.request.Request(BASE + path, data=json.dumps(body).encode(), method='POST', headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.status
        except urllib.error.HTTPError as e:
            return e.code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(attempt, zip([owner, member], paths))) == [201, 403]
    call('PATCH', paths[0] + '/' + ids[0], owner, {**body, 'story': 'Still editable'})
    call('DELETE', paths[0] + '/' + ids[0], owner, expected=204)
    status = call('GET', '/benefits', owner)
    assert status['memoryCreatedCount'] == 10 and status['memoryRemaining'] == 0
    call('POST', paths[1], owner, body, 403)
    quota = call('GET', paths[1] + '?offset=0', owner)['quota']
    assert quota['canCreateMemory'] is False and quota['memoryLimit'] == 10
    print('PASS: household-wide limit, concurrent writes, failed-create rollback, edit/delete retention')
finally:
    if member is not None:
        call('DELETE', '/account', member, expected=204)
    call('DELETE', '/account', owner, expected=204)
