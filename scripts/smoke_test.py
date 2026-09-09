"""Integration checks against a running API and real MySQL. Test accounts are cleaned up."""
import json
import os
import urllib.request
import urllib.error

BASE = os.environ.get("API_BASE_URL", "http://127.0.0.1:18080") + "/api"
tokens = []
checks = 0

def call(method, path, token=None, body=None, expected=200):
    global checks
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(BASE + path, data=None if body is None else json.dumps(body).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            status, raw = resp.status, resp.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    assert status == expected, f"{method} {path}: expected {expected}, got {status}"
    checks += 1
    return json.loads(raw) if raw else None

def session():
    token = call("POST", "/session", expected=201)["token"]
    tokens.append(token)
    return token

def main():
    try:
        assert call("GET", "/health")["database"] == "mysql"
        call("GET", "/dashboard", expected=401)
        a, b, c = session(), session(), session()
        pet = call("POST", "/pets", a, {"name": "团子 Test", "species": "cat"}, 201)["id"]
        call("POST", "/pets", a, {"name": " ", "species": "cat"}, 400)
        call("POST", "/pets", a, {"name": "Test", "species": "invalid"}, 400)
        task = call("POST", "/tasks", a, {"petId": pet, "title": "喂食", "dueAt": "2026-09-08T10:00:00Z"}, 201)["id"]
        call("POST", "/tasks", b, {"petId": pet, "title": "Forbidden", "dueAt": "2026-09-08T10:00:00Z"}, 404)
        call("PATCH", "/tasks/" + task, b, {"completed": True}, 404)
        call("DELETE", "/pets/" + pet, b, expected=404)
        assert call("GET", "/dashboard", b)["pets"] == []
        code = call("POST", "/invites", a)["code"]
        call("POST", "/join", b, {"code": code})
        call("POST", "/join", c, {"code": code}, 404)
        assert call("GET", "/dashboard", b)["members"] == 2
        assert call("GET", "/dashboard", b)["pets"][0]["name"] == "团子 Test"
        call("PATCH", "/tasks/" + task, b, {"completed": True})
        assert call("GET", "/dashboard", a)["tasks"][0]["completed"] is True
        # Setting the same state twice must remain successful.
        call("PATCH", "/tasks/" + task, b, {"completed": True})
        code_c = call("POST", "/invites", c)["code"]
        call("POST", "/join", a, {"code": code_c}, 409)
        call("DELETE", "/account", a, expected=204)
        tokens.remove(a)
        call("GET", "/dashboard", a, expected=401)
        assert call("GET", "/dashboard", b)["members"] == 1
        call("DELETE", "/pets/" + pet, b, expected=204)
        assert call("GET", "/dashboard", b)["tasks"] == []
        print(f"PASS: {checks} HTTP checks; isolation, validation, sharing, invitation reuse, deletion, cascades.")
    finally:
        for token in tokens:
            call("DELETE", "/account", token, expected=204)

if __name__ == "__main__":
    main()
