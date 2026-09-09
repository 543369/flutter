"""Password changes and session isolation against the running development API."""
from uuid import uuid4
from smoke_test import call
email = 'security-' + uuid4().hex + '@example.com'
password = 'Original-password-42'
new_password = 'Changed-password-43'
cleanup = []
try:
    a = call('POST', '/auth/register', body={'email': email, 'password': password, 'name': 'Security test'}, expected=201)['token']
    cleanup.append(a)
    b = call('POST', '/auth/login', body={'email': email, 'password': password})['token']
    guest = call('POST', '/session', expected=201)['token']
    cleanup.append(guest)
    sessions = call('GET', '/auth/sessions', a)
    assert len(sessions) == 2 and sum(s['current'] for s in sessions) == 1
    assert all('token' not in s and 'token_hash' not in s and s['createdAt'] for s in sessions)
    own = next(s['id'] for s in sessions if s['current'])
    other = next(s['id'] for s in sessions if not s['current'])
    call('DELETE', '/auth/sessions/' + other, guest, expected=404)
    call('DELETE', '/auth/sessions/' + own, a, expected=409)
    call('POST', '/auth/password', a, {'oldPassword': 'incorrect-password', 'newPassword': new_password}, 403)
    call('GET', '/dashboard', b)
    call('POST', '/auth/password', a, {'oldPassword': password, 'newPassword': password}, 400)
    call('POST', '/auth/password', a, {'oldPassword': password, 'newPassword': 'short'}, 400)
    call('POST', '/auth/password', guest, {'oldPassword': password, 'newPassword': new_password}, 409)
    call('POST', '/auth/password', a, {'oldPassword': password, 'newPassword': new_password}, 204)
    call('GET', '/dashboard', a)
    call('GET', '/dashboard', b, expected=401)
    call('POST', '/auth/login', body={'email': email, 'password': password}, expected=401)
    c = call('POST', '/auth/login', body={'email': email, 'password': new_password})['token']
    other = next(s['id'] for s in call('GET', '/auth/sessions', a) if not s['current'])
    call('DELETE', '/auth/sessions/' + other, a, expected=204)
    call('GET', '/dashboard', c, expected=401)
    d = call('POST', '/auth/login', body={'email': email, 'password': new_password})['token']
    call('POST', '/auth/sessions/revoke-others', a, expected=204)
    call('POST', '/auth/sessions/revoke-others', a, expected=204)
    call('GET', '/dashboard', d, expected=401)
    assert len(call('GET', '/auth/sessions', a)) == 1
    print('PASS: password validation, password replacement, current-session preservation, revocation, session isolation and private metadata.')
finally:
    for token in cleanup:
        call('DELETE', '/account', token, expected=204)
