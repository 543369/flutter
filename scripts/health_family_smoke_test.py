#!/usr/bin/env python3
"""Real HTTP checks against a local preview-enabled PetCare API; temporary users only."""
import base64
import json
import os
import urllib.error
import urllib.request
import uuid
import time
from datetime import datetime, timedelta, timezone

BASE = os.environ.get('PETCARE_API', 'http://127.0.0.1:18080') + '/api'
PHOTO = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII='
TOKENS = []

def call(token, method, path, body=None, expected=200):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(BASE + path, headers=headers, method=method,
        data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            status, payload = response.status, response.read()
    except urllib.error.HTTPError as exc:
        status, payload = exc.code, exc.read()
    assert status == expected, (method, path, status, expected, payload[:200])
    return json.loads(payload) if payload else None

def register():
    result = call(None, 'POST', '/auth/register', {
        'email': f'health-qa-{uuid.uuid4()}@example.com', 'password': 'Health-qa-Password-123', 'locale': 'zh-CN'}, 201)
    TOKENS.append(result['token'])
    return result['token']

def main():
    try:
        owner, member, outsider = register(), register(), register()
        pet = call(owner, 'POST', '/pets', {'name': 'QA pet', 'species': 'cat'}, 201)['id']
        path = f'/pets/{pet}/health'
        day = datetime.now(timezone.utc).date().isoformat()
        records = []
        for kind in ['VACCINE', 'DEWORMING', 'MEDICATION', 'ALLERGY', 'WEIGHT', 'VISIT']:
            body = {'kind': kind, 'title': kind, 'notes': 'Test observation', 'happenedOn': day,
                'weightKg': 4.2 if kind == 'WEIGHT' else None, 'photos': [PHOTO]}
            records.append(call(owner, 'POST', path, body, 201)['id'])
        assert call(owner, 'GET', path)['total'] == 6
        assert call(owner, 'GET', '/benefits')['usedBytes'] == len(base64.b64decode(PHOTO)) * 6
        assert len(call(owner, 'GET', path + '/trend')['items']) == 1
        call(owner, 'POST', path + '/organize', {'ids': records, 'folder': '年度检查'})
        assert call(owner, 'GET', path + '/' + records[0])['folder'] == '年度检查'
        call(owner, 'POST', path + '/organize', {'ids': [records[0], 'missing'], 'folder': 'Must rollback'}, 404)
        assert call(owner, 'GET', path + '/' + records[0])['folder'] == '年度检查'
        call(outsider, 'GET', path, expected=404)
        call(owner, 'POST', path, {'kind': 'WEIGHT', 'title': 'Invalid', 'notes': '', 'happenedOn': '2999-01-01', 'weightKg': -1, 'photos': []}, 400)
        invite = call(owner, 'POST', '/invites', {'role': 'TEMP', 'permissions': ['CARE'],
            'expiresAt': (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()})
        call(member, 'POST', '/join', {'code': invite['code']})
        call(member, 'GET', path, expected=403)
        call(member, 'GET', f'/pets/{pet}/memories', expected=403)
        call(member, 'GET', '/family/weekly', expected=403)
        call(member, 'POST', '/invites', expected=403)
        own = call(owner, 'GET', '/profile')['id']
        mid = call(member, 'GET', '/profile')['id']
        call(member, 'PATCH', '/family/members/' + own, {'role': 'MEMBER'}, 403)
        call(owner, 'PATCH', '/family/members/' + own, {'role': 'MEMBER'}, 409)
        call(owner, 'DELETE', '/account', expected=409)
        task = call(owner, 'POST', '/tasks', {'petId': pet, 'title': 'QA feeding',
            'dueAt': (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat(), 'frequency': 'NONE'}, 201)['id']
        call(owner, 'PATCH', f'/tasks/{task}/assignment', {'memberId': mid})
        call(member, 'PATCH', f'/tasks/{task}', {'completed': True})
        report = call(owner, 'GET', '/family/weekly?zoneId=Asia%2FShanghai&trends=true')
        assert report['due'] == 1 and report['completed'] == 1 and report['completionRate'] == 100
        call(member, 'PATCH', f'/tasks/{task}', {'completed': False})
        assert call(owner, 'GET', '/family/weekly')['missed'] == 1
        call(owner, 'PATCH', '/family/members/' + mid, {'role': 'TEMP', 'permissions': ['CARE'],
            'expiresAt': (datetime.now(timezone.utc) + timedelta(seconds=2)).isoformat()})
        time.sleep(2.1)
        assert call(member, 'GET', '/dashboard', expected=403)['error'] == 'ACCESS_EXPIRED'
        call(member, 'GET', '/benefits', expected=403)
        assert call(member, 'GET', '/profile')['id'] == mid
        call(owner, 'PATCH', '/family/members/' + mid, {'role': 'MEMBER'})
        assert call(member, 'GET', path)['total'] == 6
        call(owner, 'DELETE', path + '/' + records[0], expected=204)
        assert call(owner, 'GET', '/benefits')['usedBytes'] == len(base64.b64decode(PHOTO)) * 5
        print('PASS: six health kinds, attachments, batch rollback, isolation, roles, invitation, assignment and weekly statistics')
    finally:
        for token in reversed(TOKENS):
            call(token, 'DELETE', '/account', expected=204)

if __name__ == "__main__":
    main()
