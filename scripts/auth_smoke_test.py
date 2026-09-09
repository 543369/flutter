"""Registration/login/logout and legacy upgrade regression against a running API."""
from uuid import uuid4
from smoke_test import call

password='Petcare-test-password-42'
email='auth-'+uuid4().hex+'@example.com'
cleanup=[]
try:
    call('POST','/auth/register',body={'email':email,'password':'short','name':'Alex'},expected=400)
    call('POST','/auth/register',body={'email':'invalid','password':password,'name':'Alex'},expected=400)
    token=call('POST','/auth/register',body={'email':email.upper(),'password':password,'name':'Alex'},expected=201)['token']
    cleanup.append(token)
    board=call('GET','/dashboard',token)
    assert board['registered'] is True and board['me']=='Alex' and board['members']==1
    call('POST','/auth/register',body={'email':email,'password':password,'name':'Duplicate'},expected=409)
    call('POST','/auth/login',body={'email':email,'password':'incorrect-password'},expected=401)
    second=call('POST','/auth/login',body={'email':email,'password':password})['token']
    assert second!=token
    call('POST','/pets',token,{'name':'Login pet','species':'cat'},201)
    assert call('GET','/dashboard',second)['pets'][0]['name']=='Login pet'
    call('POST','/auth/logout',second,expected=204)
    call('GET','/dashboard',second,expected=401)
    assert call('GET','/dashboard',token)['registered'] is True
    call('POST','/auth/register',token,{'email':'different-'+email,'password':password,'name':'No rebind'},409)
    # Existing guest household, pet, tasks and membership are upgraded in place.
    guest=call('POST','/session',expected=201)['token']
    cleanup.append(guest)
    pet=call('POST','/pets',guest,{'name':'Original pet','species':'dog'},201)['id']
    upgrade_email='upgrade-'+email
    bound=call('POST','/auth/register',guest,{'email':upgrade_email,'password':password,'name':'Jamie'},201)['token']
    cleanup.remove(guest);cleanup.append(bound)
    call('GET','/dashboard',guest,expected=401)
    preserved=call('GET','/dashboard',bound)
    assert preserved['pets'][0]['id']==pet and preserved['registered'] is True
    call('POST','/auth/register',guest,{'email':'expired-'+email,'password':password,'name':'Expired'},401)
    restored=call('POST','/auth/login',body={'email':upgrade_email,'password':password})['token']
    assert call('GET','/dashboard',restored)['pets'][0]['id']==pet
    call('DELETE','/account',bound,expected=204)
    cleanup.remove(bound)
    call('GET','/dashboard',restored,expected=401)
    call('POST','/auth/login',body={'email':upgrade_email,'password':password},expected=401)
    print('PASS: registration, validation, normalized-email duplicates, password checks, multiple sessions, logout revocation, in-place guest upgrade, stale token rejection, account deletion.')
finally:
    for token in cleanup:
        call('DELETE','/account',token,expected=204)
