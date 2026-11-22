#!/usr/bin/env python3
"""
DiaMate API robustness scan ("no 500" scan): calls every endpoint with broken input and reports any answer that is
- a 5xx (a bug: bad input must be a 4xx),
- an error that is not application/problem+json (every error has the same RFC 9457 shape), or
- slower than --slow seconds.

Each field of each JSON body, each query parameter and each path id gets a list of bad values in turn while the rest
of the request stays valid; whole bodies (not JSON, an array, 2 MB, duplicate keys ...) and Authorization headers are
tried as well. Only the Python standard library is used.

It registers its own accounts and writes data, so it runs ONLY against a local backend connected to a local database:
    python3 tools/api_fuzz_scan.py                       # http://localhost:8081/api/v1
    python3 tools/api_fuzz_scan.py --base http://localhost:8080/api/v1
Exit code 0 when nothing is found, 1 otherwise. Uses the seeded demo accounts (Database/docs/DEMO_ACCOUNTS.md).
"""
import argparse
import copy
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

DEMO_PASSWORD = "DiaMate!2026"  # seeded demo accounts, local database only
TEST_PASSWORD = "Scan-Robust-4417x"

# Values that are wrong for most fields in some way: type, size, format, encoding, range.
BAD_VALUES = [
    None, "", " ", "abc", "\u0000", "a\u0001b", "😀", "x" * 10_000, 0, -1, 1.5, -0.0, 2**31, 2**63, 2**64, -(2**63) - 1,
    1e308, 1e-308, "1e999999999", True, False, [], [1], {}, {"a": 1}, "NaN", "Infinity",
    "-1000000000-01-01T00:00:00Z", "+1000000000-12-31T23:59:59Z", "0000-01-01T00:00:00Z", "2026-13-45T25:61:61Z",
    "9999-12-31T23:59:59Z", "1899-12-31T23:59:59Z", "2026-10-05", "2026-10-05T08:30:00", "2026-10-05T08:30:00+25:00",
    "<script>alert(1)</script>", "' OR '1'='1", "../../etc/passwd", "%00", "${jndi:ldap://x}",
]
BAD_QUERY = ["", "abc", "-1", "0", "1.5", "99999999999999999999", "9223372036854775808", "-9223372036854775809",
             "NaN", "true", "%00", "\u0000", "x" * 5000, "2026-13-45T25:61:61Z", "-1000000000-01-01T00:00:00Z",
             "+1000000000-12-31T23:59:59Z", "' OR 1=1--", "2147483647", "2147483648", "1e308"]
BAD_IDS = ["0", "-1", "abc", "1.5", "9223372036854775807", "9223372036854775808", "99999999999999999999", "%20",
           "1;DROP", "..", "%2e%2e", "1%3B", "😀", "x" * 3000]
# Answers that are known and accepted (README "Hata cevapları" / B-22): Tomcat rejects %00 and %2F in the path, and a
# request header above 8 KB, before Spring sees the request, with a short HTML page (400, no version or details).
TOMCAT_HTML_OK = ("%00", "%2F", "%2f")
TOMCAT_HEADER_LIMIT = 8192


class Scanner:
    def __init__(self, base, slow):
        self.base = base.rstrip("/")
        self.slow = slow
        self.findings = []
        self.count = 0
        self.skipped = 0
        self.accepted = {}  # "label without the value" -> bad values answered with 2xx (to review by hand)
        self.statuses = {}

    # ---------- HTTP ----------

    def raw(self, method, path, token=None, body=None, content_type="application/json", headers=None):
        # Non-ASCII characters are sent percent-encoded (as a browser or the app would); "%" stays as written.
        url = self.base + urllib.parse.quote(path, safe="/%?=&:+;,._~-!$'()*@")
        data = body if isinstance(body, (bytes, type(None))) else body.encode("utf-8")
        req = urllib.request.Request(url, data=data, method=method)
        if data is not None and content_type:
            req.add_header("Content-Type", content_type)
        if token:
            req.add_header("Authorization", "Bearer " + token)
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        start = time.monotonic()
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                status, ctype, raw = r.status, r.headers.get("Content-Type", ""), r.read()
        except urllib.error.HTTPError as e:
            status, ctype, raw = e.code, e.headers.get("Content-Type", ""), e.read()
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            status, ctype, raw = 0, "", str(e).encode()
        except (ValueError, UnicodeError) as e:  # the client library refuses to send it (e.g. a header it cannot encode)
            self.skipped += 1
            return -1, "", str(e).encode(), 0.0
        return status, ctype, raw, time.monotonic() - start

    def json_call(self, method, path, token=None, body=None):
        status, _, raw, _ = self.raw(method, path, token, None if body is None else json.dumps(body))
        try:
            return status, json.loads(raw) if raw else None
        except ValueError:
            return status, raw.decode(errors="replace")

    def check(self, label, method, path, token=None, body=None, **kw):
        status, ctype, raw, took = self.raw(method, path, token, body, **kw)
        self.count += 1
        problem = None
        if status == -1:
            return status
        self.statuses[status] = self.statuses.get(status, 0) + 1
        if 200 <= status < 300 and "=" in label:
            field, value = label.split("=", 1)
            self.accepted.setdefault(field, []).append(value)
        if status == 0:
            problem = "no answer (" + raw.decode(errors="replace")[:80] + ")"
        elif status >= 500:
            problem = f"{status}"
        elif status >= 400 and "application/problem+json" not in ctype:
            if not (status == 400 and any(t in path for t in TOMCAT_HTML_OK)):
                problem = f"{status} not problem+json ({ctype or 'no content type'})"
        if problem is None and took > self.slow:
            problem = f"slow: {took:.1f}s"
        if problem:
            shown = body if body is None or len(body) < 200 else body[:200] + "..."
            self.findings.append((problem, label, method, path[:160], shown, raw[:300].decode(errors="replace")))
        return status

    # ---------- mutations ----------

    def body_fields(self, label, method, path, token, valid, prefix=""):
        """Each field of the body (and of nested objects / the first array element) gets every bad value."""
        for key in list(valid.keys()):
            for bad in BAD_VALUES:
                body = copy.deepcopy(valid)
                body[key] = bad
                self.check(f"{label} {prefix}{key}={json.dumps(bad)[:40]}", method, path, token, json.dumps(body))
            missing = copy.deepcopy(valid)
            del missing[key]
            self.check(f"{label} {prefix}{key} missing", method, path, token, json.dumps(missing))
            value = valid[key]
            if isinstance(value, list) and value and isinstance(value[0], dict):
                for inner_key in value[0]:
                    for bad in BAD_VALUES:
                        body = copy.deepcopy(valid)
                        body[key][0][inner_key] = bad
                        self.check(f"{label} {key}[0].{inner_key}={json.dumps(bad)[:40]}", method, path, token,
                                   json.dumps(body))

    def whole_bodies(self, label, method, path, token, valid):
        text = json.dumps(valid)
        first_key = next(iter(valid), "a")
        for name, body, ctype in [
            ("not JSON", "{not json", "application/json"),
            ("empty", "", "application/json"),
            ("null", "null", "application/json"),
            ("array", "[" + text + "]", "application/json"),
            ("string", '"x"', "application/json"),
            ("number", "1", "application/json"),
            ("duplicate key", text[:-1] + f', "{first_key}": 1}}' if text != "{}" else '{"a":1,"a":2}', "application/json"),
            ("deep nesting", "[" * 5000 + "]" * 5000, "application/json"),
            ("2 MB", '{"x":"' + "a" * 2_100_000 + '"}', "application/json"),
            ("unknown field", text[:-1] + ', "zzz": 1}' if text != "{}" else '{"zzz":1}', "application/json"),
            ("text/plain", text, "text/plain"),
            ("form", "a=1", "application/x-www-form-urlencoded"),
            ("no content type", text, None),
            ("bad UTF-8", b'{"a":"\xff\xfe"}', "application/json"),
        ]:
            self.check(f"{label} body {name}", method, path, token, body, content_type=ctype)

    def query(self, label, path, token, params):
        for key in params:
            for bad in BAD_QUERY:
                q = dict(params)
                q[key] = bad
                self.check(f"{label} ?{key}={bad[:30]}", "GET", path + "?" + urllib.parse.urlencode(q), token)
        self.check(f"{label} repeated params", "GET", path + "?" + "&".join(f"{k}=1&{k}=2" for k in params), token)

    def path_ids(self, label, method, template, token, ids, body=None):
        """template like /patients/{p}/glucose-logs/{l}; ids: the valid values; each one replaced in turn."""
        for name in ids:
            for bad in BAD_IDS:
                values = dict(ids)
                values[name] = bad
                self.check(f"{label} {{{name}}}={bad[:30]}", method, template.format(**values), token,
                           None if body is None else json.dumps(body))


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", default="http://localhost:8081/api/v1")
    parser.add_argument("--slow", type=float, default=2.0, help="seconds after which an answer counts as slow")
    parser.add_argument("--accepted", action="store_true", help="also list the bad values that were answered with 2xx")
    args = parser.parse_args()
    host = urllib.parse.urlparse(args.base).hostname
    if host not in ("localhost", "127.0.0.1", "::1"):
        sys.exit("Refusing to scan " + str(host) + ": the scan writes data; run it against a local backend only.")

    s = Scanner(args.base, args.slow)
    now = datetime.now(timezone.utc)
    earlier = iso(now - timedelta(hours=1))

    # ---------- accounts and data ----------
    stamp = str(int(time.time() * 1000))
    def register(first, role):
        email = f"scan.{role.lower()}.{stamp}@diamate.test"
        st, b = s.json_call("POST", "/auth/register", body={"firstName": first, "lastName": "Scan", "email": email,
                            "password": TEST_PASSWORD, "role": role, "dateOfBirth": "1990-01-01", "gender": "OTHER"})
        assert st == 201, (st, b)
        return email

    def login(email, password):
        st, b = s.json_call("POST", "/auth/login", body={"email": email, "password": password})
        assert st == 200, (email, st, b)
        return b["accessToken"], b["user"]["id"]

    patient_email = register("Pat", "PATIENT")
    target_email = register("Target", "CAREGIVER")  # the account the admin status endpoint is aimed at
    pt, pid = login(patient_email, TEST_PASSWORD)
    _, target_id = login(target_email, TEST_PASSWORD)
    dt, _ = login("dr.diabetes@diamate.example", DEMO_PASSWORD)
    ct, _ = login("caregiver@diamate.example", DEMO_PASSWORD)
    at, _ = login("admin@diamate.example", DEMO_PASSWORD)

    st, rel = s.json_call("POST", "/care-relationships", pt, {"memberEmail": "dr.diabetes@diamate.example"})
    assert st == 201, (st, rel)
    rel_id = rel["id"]
    assert s.json_call("POST", f"/care-relationships/{rel_id}/accept", dt)[0] == 200
    st, rel2 = s.json_call("POST", "/care-relationships", pt, {"memberEmail": "caregiver@diamate.example"})
    assert st == 201, (st, rel2)
    try:
        scan(s, now, earlier, pid, pt, dt, at, target_id, rel_id, rel2["id"])
    finally:
        # Never leave sharing behind, even after a crash: the demo doctor's and caregiver's patient lists are checked
        # exactly by the Postman collection.
        for open_id in (rel_id, rel2["id"]):
            s.json_call("DELETE", f"/care-relationships/{open_id}", pt)
    report(s)


def scan(s, now, earlier, pid, pt, dt, at, target_id, rel_id, rel2_id):

    valid = {
        "glucose-logs": {"glucoseValue": 300, "measurementTime": earlier, "mealContext": "FASTING", "notes": "n",
                         "source": "MANUAL", "clientUuid": None},
        "insulin-logs": {"doseUnits": 4, "insulinType": "RAPID", "deliveryMethod": "PEN", "productName": "x",
                         "administeredAt": earlier, "mealLogId": None, "notes": "n", "source": "MANUAL",
                         "clientUuid": None},
        "meal-logs": {"mealType": "LUNCH", "eatenAt": earlier, "description": "d", "carbsG": 40, "caloriesKcal": 500,
                      "proteinG": 20, "fatG": 10, "notes": "n", "source": "MANUAL", "clientUuid": None},
        "activity-logs": {"activityType": "walking", "startedAt": earlier, "durationMinutes": 30, "steps": 3000,
                          "avgHeartRate": 100, "caloriesKcal": 120, "intensity": "LOW", "notes": "n",
                          "source": "MANUAL", "clientUuid": None},
    }
    log_ids = {}
    for kind, body in valid.items():
        st, b = s.json_call("POST", f"/patients/{pid}/{kind}", pt, body)
        assert st == 201, (kind, st, b)
        log_ids[kind] = b["id"]
    st, alerts = s.json_call("GET", f"/patients/{pid}/alerts?status=OPEN", pt)
    alert_id = alerts["items"][0]["id"]

    # ---------- public and account endpoints ----------
    register_body = {"firstName": "A", "lastName": "B", "email": "x@diamate.test", "password": TEST_PASSWORD,
                     "role": "PATIENT", "dateOfBirth": "1990-01-01", "gender": "FEMALE"}
    s.body_fields("register", "POST", "/auth/register", None, register_body)
    s.whole_bodies("register", "POST", "/auth/register", None, register_body)
    login_body = {"email": "nobody@diamate.test", "password": "wrong-password-1"}
    s.body_fields("login", "POST", "/auth/login", None, login_body)
    s.whole_bodies("login", "POST", "/auth/login", None, login_body)
    s.check("health", "GET", "/health")
    s.check("me", "GET", "/users/me", pt)

    # ---------- Authorization header ----------
    for name, value in [("empty", ""), ("Bearer only", "Bearer"), ("Bearer space", "Bearer "),
                        ("garbage", "Bearer abc.def.ghi"), ("Basic", "Basic YTpi"), ("long", "Bearer " + "a" * 9000),
                        ("two dots", "Bearer .."), ("unicode", "Bearer ü"), ("alg none", "Bearer eyJhbGciOiJub25lIn0.e30.")]:
        status, ctype, raw, took = s.raw("GET", "/users/me", headers={"Authorization": value})
        s.count += 1
        tomcat_limit = len(value) > TOMCAT_HEADER_LIMIT and status == 400
        if status >= 500 or (status >= 400 and "problem+json" not in ctype and not tomcat_limit):
            s.findings.append((f"{status} {ctype}", "auth header " + name, "GET", "/users/me", None, raw[:200].decode(errors="replace")))

    # ---------- admin ----------
    s.check("admin users", "GET", "/admin/users", at)
    s.body_fields("admin status", "PATCH", f"/admin/users/{target_id}/status", at, {"active": True})
    s.whole_bodies("admin status", "PATCH", f"/admin/users/{target_id}/status", at, {"active": True})
    s.path_ids("admin status", "PATCH", "/admin/users/{u}/status", at, {"u": target_id}, {"active": True})
    s.query("audit search", "/admin/audit-logs", at,
            {"userId": "1", "patientId": str(pid), "action": "LOGIN", "success": "true", "from": iso(now - timedelta(days=1)),
             "to": iso(now + timedelta(minutes=1)), "page": "0", "size": "10"})

    # ---------- care team and relationships ----------
    s.check("care-team patients", "GET", "/care-team/patients", dt)
    s.query("care-team alerts", "/care-team/alerts", dt, {"status": "OPEN", "page": "0", "size": "10"})
    invite = {"memberEmail": "nobody@diamate.test", "canViewGlucose": True, "canViewMeals": True,
              "canViewMedications": True, "canViewActivity": True, "canViewReports": True, "canReceiveAlerts": True,
              "canAddRecommendations": False, "expiresAt": iso(now + timedelta(days=7))}
    s.body_fields("invite", "POST", "/care-relationships", pt, invite)
    s.whole_bodies("invite", "POST", "/care-relationships", pt, invite)
    s.query("relationships", "/care-relationships", pt, {"status": "ACTIVE"})
    for action in ("accept", "decline"):
        s.path_ids(action, "POST", "/care-relationships/{r}/" + action, dt, {"r": rel_id})
    perms = {"canViewGlucose": True, "canViewMeals": True, "canViewMedications": True, "canViewActivity": True,
             "canViewReports": True, "canReceiveAlerts": True, "canAddRecommendations": False,
             "expiresAt": iso(now + timedelta(days=30)), "removeExpiry": None}
    s.body_fields("permissions", "PATCH", f"/care-relationships/{rel_id}", pt, perms)
    s.whole_bodies("permissions", "PATCH", f"/care-relationships/{rel_id}", pt, perms)
    s.path_ids("permissions", "PATCH", "/care-relationships/{r}", pt, {"r": rel_id}, {"canViewMeals": True})
    s.json_call("PATCH", f"/care-relationships/{rel_id}", pt, {"removeExpiry": True, "canViewMeals": True,
                                                                 "canViewGlucose": True, "canReceiveAlerts": True})

    # ---------- patient data ----------
    window = {"from": iso(now - timedelta(days=2)), "to": iso(now + timedelta(minutes=1)), "page": "0", "size": "10"}
    s.path_ids("overview", "GET", "/patients/{p}/overview", dt, {"p": pid})
    for kind, body in valid.items():
        base = f"/patients/{pid}/{kind}"
        s.body_fields(kind + " POST", "POST", base, pt, body)
        s.whole_bodies(kind + " POST", "POST", base, pt, body)
        s.query(kind + " list", base, dt, window)
        s.path_ids(kind + " GET", "GET", "/patients/{p}/" + kind + "/{l}", dt, {"p": pid, "l": log_ids[kind]})
        s.body_fields(kind + " PUT", "PUT", f"{base}/{log_ids[kind]}", pt, body)
        s.whole_bodies(kind + " PUT", "PUT", f"{base}/{log_ids[kind]}", pt, body)
        s.path_ids(kind + " PUT", "PUT", "/patients/{p}/" + kind + "/{l}", pt, {"p": pid, "l": log_ids[kind]}, body)
    s.query("alerts list", f"/patients/{pid}/alerts", dt, {"status": "OPEN", **window})
    s.path_ids("alert GET", "GET", "/patients/{p}/alerts/{a}", dt, {"p": pid, "a": alert_id})
    s.body_fields("alert PATCH", "PATCH", f"/patients/{pid}/alerts/{alert_id}", dt, {"status": "ACKNOWLEDGED"})
    s.whole_bodies("alert PATCH", "PATCH", f"/patients/{pid}/alerts/{alert_id}", dt, {"status": "ACKNOWLEDGED"})
    s.query("access log", f"/patients/{pid}/access-log", pt, window)

    # ---------- AI ----------
    entries = {"entries": [{"intent": "LOG_GLUCOSE", "value": 120.0, "unit": "mg/dL", "activity": None,
                            "clientUuid": str(uuid.uuid4()), "at": earlier, "mealType": None, "mealContext": None}]}
    s.body_fields("ai-entries", "POST", f"/patients/{pid}/ai-entries", pt, entries)
    s.whole_bodies("ai-entries", "POST", f"/patients/{pid}/ai-entries", pt, entries)
    s.body_fields("ai parse", "POST", "/ai/parse", pt, {"text": "my glucose is 120"})
    s.query("ai summary", f"/ai/patients/{pid}/summary", dt,
            {"from": iso(now - timedelta(days=2)), "to": iso(now + timedelta(minutes=1)), "rangeLow": "70",
             "rangeHigh": "180"})

    # ---------- deletes last (path ids only) ----------
    for kind in valid:
        s.path_ids(kind + " DELETE", "DELETE", "/patients/{p}/" + kind + "/{l}", pt, {"p": pid, "l": log_ids[kind]})
    s.path_ids("revoke", "DELETE", "/care-relationships/{r}", pt, {"r": rel2_id})


def report(s):
    print(f"{s.count - s.skipped} requests, {len(s.findings)} findings ({s.skipped} not sendable by the client)")
    print("status codes:", dict(sorted(s.statuses.items())))
    if "--accepted" in sys.argv:
        print("\nBad values answered with 2xx (not an error by itself; check that each one is meant to be valid):")
        for field, values in sorted(s.accepted.items()):
            print(f"  {field}: {', '.join(values)}")
    by_problem = {}
    for f in s.findings:
        by_problem.setdefault(f[0].split(" ")[0], []).append(f)
    for problem, rows in sorted(by_problem.items()):
        print(f"\n== {problem}: {len(rows)}")
        for p, label, method, path, body, answer in rows[:25]:
            print(f"  [{p}] {label}\n      {method} {path}\n      body: {body}\n      -> {answer[:200]}")
    sys.exit(1 if s.findings else 0)


if __name__ == "__main__":
    main()
