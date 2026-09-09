"""Real MySQL recurring care, household history and race regression checks."""
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor
from smoke_test import call, session, tokens


def due(hours):
    return (datetime.now(timezone.utc) + timedelta(hours=hours)).isoformat()

try:
    a,b,outsider = session(),session(),session()
    call("PATCH","/profile",a,{"name":"Alex"})
    call("PATCH","/profile",b,{"name":"Jamie"})
    code=call("POST","/invites",a)["code"]
    call("POST","/join",b,{"code":code})
    pet=call("POST","/pets",a,{"name":"Mochi","species":"cat"},201)["id"]
    base={"petId":pet,"title":"Morning meal","dueAt":due(-1),"frequency":"DAILY","zoneId":"Asia/Shanghai"}
    plan=call("POST","/tasks",a,base,201)
    board=call("GET","/dashboard",a)
    occurrences=[t for t in board["tasks"] if t["planId"]==plan["planId"]]
    assert 30 <= len(occurrences) <= 32
    assert len({t["dueAt"] for t in occurrences}) == len(occurrences)
    assert board["plans"][0]["active"] is True
    assert len(call("GET","/dashboard",b)["tasks"])==len(occurrences)
    call("POST","/tasks",a,{**base,"zoneId":"Wrong/Zone"},400)
    call("POST","/tasks",a,{**base,"frequency":"MONTHLY"},400)
    call("POST","/tasks",a,{**base,"zoneId":None},400)
    call("POST","/tasks",outsider,base,404)
    call("DELETE","/plans/"+plan["planId"],outsider,expected=404)
    task=occurrences[0]["id"]
    # Two members racing for the same state must create exactly one event.
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures=[pool.submit(call,"PATCH","/tasks/"+task,token,{"completed":True}) for token in (a,b)]
        for f in futures: f.result()
    events=call("GET","/dashboard",b)["history"]
    assert len(events)==1 and events[0]["actor"] in ("Alex","Jamie")
    assert events[0]["action"]=="COMPLETED" and events[0]["at"]
    call("PATCH","/tasks/"+task,b,{"completed":False})
    board=call("GET","/dashboard",a)
    assert board["history"][0]["action"]=="REOPENED" and board["history"][0]["actor"]=="Jamie"
    assert len(board["history"])==2
    # Future care that has been completed then undone must keep its history on stop.
    future=occurrences[1]["id"]
    call("PATCH","/tasks/"+future,a,{"completed":True})
    call("PATCH","/tasks/"+future,b,{"completed":False})
    call("DELETE","/plans/"+plan["planId"],a,expected=204)
    call("DELETE","/plans/"+plan["planId"],a,expected=204)
    board=call("GET","/dashboard",b)
    assert len(board["tasks"])==1 and board["tasks"][0]["id"]==task
    assert len(board["history"])==4 and board["plans"][0]["active"] is False
    call("PATCH","/tasks/"+future,a,{"completed":True},404)
    assert len(call("GET","/dashboard",a)["tasks"])==1
    assert call("GET","/dashboard",outsider)["history"]==[]
    weekly=call("POST","/tasks",a,{**base,"frequency":"WEEKLY","dueAt":due(1)},201)
    weekly_tasks=[t for t in call("GET","/dashboard",b)["tasks"] if t["planId"]==weekly["planId"]]
    assert len(weekly_tasks)==5
    times=[datetime.fromisoformat(t["dueAt"].replace("Z","+00:00")) for t in weekly_tasks]
    assert all(y-x==timedelta(days=7) for x,y in zip(times,times[1:]))
    call("DELETE","/account",b,expected=204)
    tokens.remove(b)
    board=call("GET","/dashboard",a)
    assert any(e["actor"] is None for e in board["history"])
    print("PASS: recurring generation, DST unit coverage, household isolation, concurrent completion deduplication, undo history, stop preservation, weekly intervals, actor deletion.")
finally:
    for token in tokens:
        call("DELETE","/account",token,expected=204)
