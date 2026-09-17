"""HTTP regression for daily-care improvements; uses and cleans its own accounts."""
from datetime import datetime, timedelta, timezone
from smoke_test import call, session, tokens

now = datetime.now(timezone.utc)
due = (now + timedelta(hours=1)).isoformat()
try:
    owner, outsider = session(), session()
    pet = call('POST', '/pets', owner, {'name': 'Care rounds', 'species': 'cat', 'photos': ['AA==']}, 201)['id']
    compact = call('GET', '/dashboard?compact=true', owner)
    row = compact['pets'][0]
    assert 'photos' not in row and 'photoData' not in row
    revision = row['photoRevision']
    assert call('GET', f'/pets/{pet}/photos', owner)['photos'] == ['AA==']
    call('GET', f'/pets/{pet}/photos', outsider, expected=404)
    call('PATCH', f'/pets/{pet}', owner, {'name': 'Care rounds', 'species': 'cat', 'photos': []})
    gallery = call('GET', f'/pets/{pet}/photos', owner)
    assert gallery['photoRevision'] > revision and gallery['photos'] == []
    plan = call('POST', '/tasks', owner, {'petId': pet, 'title': 'Meal', 'dueAt': due, 'frequency': 'DAILY', 'zoneId': 'Asia/Shanghai'}, 201)
    task = plan['id']
    initial = len(call('GET', '/dashboard?compact=true', owner)['tasks'])
    changed = call('PATCH', f'/tasks/{task}/schedule', owner, {'dueAt': (now + timedelta(hours=25)).isoformat()})
    assert changed['task']['id'] == task and changed['events'][0]['action'] == 'RESCHEDULED'
    assert len(call('GET', '/dashboard?compact=true', owner)['tasks']) == initial
    changed = call('PATCH', f'/tasks/{task}/disposition', owner, {'action': 'SKIPPED'})
    assert changed['task']['skipped'] and not changed['task']['completed']
    call('PATCH', f'/tasks/{task}/disposition', owner, {'action': 'SKIPPED'})
    assert len(call('GET', f'/tasks/{task}', owner)['events']) == 2
    assert call('GET', f'/tasks?petId={pet}&state=inactive', owner)['items'][0]['id'] == task
    call('GET', f'/tasks/{task}', outsider, expected=404)
    record = call('POST', f'/pets/{pet}/health', owner, {'kind': 'VACCINE', 'title': 'Follow-up', 'notes': '', 'happenedOn': now.date().isoformat(), 'weightKg': None, 'photos': []}, 201)['id']
    path = f'/pets/{pet}/health/{record}'
    linked = call('POST', path + '/reminder', owner, {'dueAt': due})['task']
    assert linked['healthRecordId'] == record
    assert call('POST', path + '/reminder', owner, {'dueAt': due})['task']['id'] == linked['id']
    detail = call('GET', path, owner)
    assert isinstance(detail['careReminders'][0]['dueAt'], str)
    done = call('PATCH', f"/tasks/{linked['id']}", owner, {'completed': True})
    assert done['task']['completed'] and done['task']['completedAt']
    assert done['events'][0]['action'] == 'COMPLETED'
    history = call('GET', f'/care/history?petId={pet}', owner)
    assert len(history['items']) == 3 and history['hasMore'] is False
    call('GET', f'/care/history?petId={pet}&cursor=invalid', owner, expected=400)
    assert len(call('GET', '/dashboard?compact=true', owner)['history']) == 2
    print('PASS: compact dashboard, gallery revisions, occurrence identity, skip idempotency, health links, partial state, history and authorization.')
finally:
    for token in tokens:
        call('DELETE', '/account', token, expected=204)
