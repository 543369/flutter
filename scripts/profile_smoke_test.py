"""Pet profile and typed care integration checks using disposable test identities."""
from datetime import datetime, timedelta, timezone
from smoke_test import call, session, tokens


try:
    owner, outsider = session(), session()
    profile = {"name": "Profile test", "species": "cat", "biography": "Loves sunshine.",
               "birthDate": "2020-02-29", "photoData": None}
    pet_id = call("POST", "/pets", owner, profile, 201)["id"]
    pet = call("GET", "/dashboard", owner)["pets"][0]
    assert pet["birthDate"] == "2020-02-29" and pet["biography"] == profile["biography"]
    created = pet["createdAt"]
    assert created and abs((datetime.now(timezone.utc) - datetime.fromisoformat(created.replace("Z", "+00:00"))).total_seconds()) < 60
    edited = {**profile, "name": "Updated profile", "biography": "Gentle and curious."}
    call("PATCH", "/pets/" + pet_id, owner, edited)
    pet = call("GET", "/dashboard", owner)["pets"][0]
    assert pet["createdAt"] == created and pet["biography"] == edited["biography"]
    call("PATCH", "/pets/" + pet_id, outsider, edited, 404)
    tomorrow = (datetime.now(timezone.utc) + timedelta(days=2)).date().isoformat()
    call("POST", "/pets", owner, {**profile, "birthDate": tomorrow}, 400)
    call("POST", "/pets", owner, {**profile, "birthDate": "2023-02-29"}, 400)
    call("POST", "/pets", owner, {**profile, "biography": "x" * 1001}, 400)
    call("PATCH", "/pets/" + pet_id, owner, {**edited, "birthDate": None})
    assert call("GET", "/dashboard", owner)["pets"][0]["birthDate"] is None
    legacy_id = call("POST", "/pets", owner, {"name": "Legacy client", "species": "dog"}, 201)["id"]
    legacy = next(p for p in call("GET", "/dashboard", owner)["pets"] if p["id"] == legacy_id)
    assert legacy["birthDate"] is None and legacy["createdAt"]

    base = {"petId": pet_id, "title": "Custom title", "frequency": "NONE",
            "dueAt": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()}
    for care_type in ("FEEDING", "DEWORMING", "VACCINE", "WALK", "GROOMING", "CUSTOM"):
        task_id = call("POST", "/tasks", owner, {**base, "careType": care_type}, 201)["id"]
        task = next(t for t in call("GET", "/dashboard", owner)["tasks"] if t["id"] == task_id)
        assert task["careType"] == care_type and task["title"] == "Custom title"
        call("PATCH", "/tasks/" + task_id, owner, {"completed": True})
        event = next(e for e in call("GET", "/dashboard", owner)["history"] if e["taskId"] == task_id)
        assert event["careType"] == care_type
    call("POST", "/tasks", owner, {**base, "careType": "INVALID"}, 400)
    old_task_id = call("POST", "/tasks", owner, base, 201)["id"]
    assert next(t for t in call("GET", "/dashboard", owner)["tasks"] if t["id"] == old_task_id)["careType"] == "CUSTOM"
    plan_id = call("POST", "/tasks", owner, {**base, "frequency": "WEEKLY", "zoneId": "Asia/Shanghai", "careType": "GROOMING"}, 201)["planId"]
    board = call("GET", "/dashboard", owner)
    assert next(p for p in board["plans"] if p["id"] == plan_id)["careType"] == "GROOMING"
    occurrences = [t for t in board["tasks"] if t["planId"] == plan_id]
    assert len(occurrences) >= 4 and all(t["careType"] == "GROOMING" for t in occurrences)
    assert call("GET", "/dashboard", outsider)["pets"] == []
    print("PASS: profiles, birthday validation, stable server creation time, legacy clients, household isolation, six care types, history and recurring type propagation.")
finally:
    for token in tokens:
        call("DELETE", "/account", token, expected=204)
