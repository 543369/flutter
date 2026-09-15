#!/usr/bin/env python3
"""Use a dedicated API with preview off and free storage set to 150 bytes."""
import base64
from datetime import datetime, timezone
from health_family_smoke_test import call, register, PHOTO, TOKENS

try:
    owner = register()
    status = call(owner, 'GET', '/benefits')
    assert status['tier'] == 'FREE' and status['limitBytes'] == 150
    pet = call(owner, 'POST', '/pets', {'name': 'Free health QA', 'species': 'dog'}, 201)['id']
    path = f'/pets/{pet}/health'
    body = {'kind': 'VISIT', 'title': 'Vet notes', 'notes': 'Observation',
        'happenedOn': datetime.now(timezone.utc).date().isoformat(), 'photos': [PHOTO, PHOTO, PHOTO]}
    call(owner, 'POST', path, body, 403)
    assert call(owner, 'GET', path)['total'] == 0
    body['photos'] = [PHOTO, PHOTO]
    record = call(owner, 'POST', path, body, 201)['id']
    body['photos'] = [PHOTO]
    call(owner, 'POST', path, body, 413)
    assert call(owner, 'GET', path)['total'] == 1
    assert call(owner, 'GET', '/benefits')['usedBytes'] == len(base64.b64decode(PHOTO)) * 2
    call(owner, 'GET', path + '/trend', expected=403)
    call(owner, 'POST', path + '/organize', {'ids': [record], 'folder': 'Premium'}, 403)
    call(owner, 'POST', '/invites', {'role': 'TEMP'}, 403)
    assert call(owner, 'GET', '/family/weekly')['completionRate'] is None
    call(owner, 'GET', '/family/weekly?trends=true', expected=403)
    body['photos'] = []
    call(owner, 'PATCH', path + '/' + record, body)
    assert call(owner, 'GET', '/benefits')['usedBytes'] == 0
    print('PASS: free entry, attachment limits, quota rollback, premium guards, capacity released')
finally:
    for token in reversed(TOKENS):
        call(token, 'DELETE', '/account', expected=204)
