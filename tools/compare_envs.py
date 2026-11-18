#!/usr/bin/env python3
"""Compare two environments of an Apigee X/hybrid org (read-only).

Checks that DST has what SRC has:
  - proxy and shared flow deployments (same revision) and, for DST, that each
    deployment is READY (a deploy call can be accepted and still fail later)
  - target servers (by name)
  - key value maps (by name and entry count)

    APIGEE_TOKEN=$(gcloud auth print-access-token) \
        tools/compare_envs.py --org corp-apigee dev tdtest

Only GET requests are sent. The token is read from APIGEE_TOKEN (or
`gcloud auth print-access-token`) and never printed. Exit status: 0 when
everything matches, 1 when something differs, 2 on usage or request errors.
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(2)


class Api:
    def __init__(self, base, token):
        self.base, self.token = base.rstrip("/"), token

    def get(self, path, **params):
        url = f"{self.base}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {self.token}"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read().decode() or "{}"
        except urllib.error.HTTPError as e:
            die(f"GET {path} -> HTTP {e.code}: {e.read().decode()[:200]}")
        except urllib.error.URLError as e:
            die(f"GET {path}: {e.reason}")
        return json.loads(body)


def get_token():
    tok = os.environ.get("APIGEE_TOKEN", "").strip()
    if tok:
        return tok
    try:
        out = subprocess.run(["gcloud", "auth", "print-access-token"], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        out = None
    if out is None or out.returncode != 0 or not out.stdout.strip():
        die("set APIGEE_TOKEN or log in with gcloud")
    return out.stdout.strip()


def deployments(api, org, env, shared):
    params = {"sharedFlows": "true"} if shared else {}
    data = api.get(f"/v1/organizations/{org}/environments/{env}/deployments", **params)
    return {d["apiProxy"]: d for d in data.get("deployments", [])}


def state_of(api, org, env, kind, name, rev):
    data = api.get(f"/v1/organizations/{org}/environments/{env}/{kind}/{name}/revisions/{rev}/deployments")
    return data.get("state") or "UNKNOWN"


def names(api, path, key):
    data = api.get(path)
    if isinstance(data, list):
        return [x if isinstance(x, str) else x.get("name", "") for x in data]
    return [x if isinstance(x, str) else x.get("name", "") for x in data.get(key, [])]


def entry_count(api, org, env, kvm):
    n, token = 0, None
    while True:
        params = {"pageSize": "1000"}
        if token:
            params["pageToken"] = token
        d = api.get(f"/v1/organizations/{org}/environments/{env}/keyvaluemaps/{urllib.parse.quote(kvm, safe='')}/entries", **params)
        n += len(d.get("keyValueEntries", []))
        token = d.get("nextPageToken")
        if not token:
            return n


def main():
    ap = argparse.ArgumentParser(description="Compare two Apigee X environments (read-only).")
    ap.add_argument("--org", required=True)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--base-url", default="https://apigee.googleapis.com")
    ap.add_argument("--no-state", action="store_true", help="skip the per-deployment READY check (faster)")
    a = ap.parse_args()

    api = Api(a.base_url, get_token())
    problems = 0

    def report(label, ok, detail=""):
        nonlocal problems
        print(f"  {'ok  ' if ok else 'DIFF'}  {label}{': ' + detail if detail else ''}")
        problems += 0 if ok else 1

    for kind, shared, title in (("sharedflows", True, "shared flows"), ("apis", False, "proxies")):
        print(f"{title}")
        s, d = deployments(api, a.org, a.src, shared), deployments(api, a.org, a.dst, shared)
        report(f"{len(s)} deployed in {a.src}, {len(d)} in {a.dst}", len(s) <= len(d) and set(s) <= set(d))
        missing = sorted(set(s) - set(d))
        if missing:
            report("not deployed in " + a.dst, False, ", ".join(missing))
        wrong = sorted(n for n in s if n in d and s[n].get("revision") != d[n].get("revision"))
        if wrong:
            report("different revision", False, ", ".join(f"{n} ({a.src} {s[n].get('revision')}, {a.dst} {d[n].get('revision')})" for n in wrong))
        sa_diff = sorted(n for n in s if n in d and s[n].get("serviceAccount") != d[n].get("serviceAccount"))
        if sa_diff:
            report("different service account", False, ", ".join(sa_diff))
        if not a.no_state:
            bad = []
            for n in sorted(d):
                st = state_of(api, a.org, a.dst, kind, n, d[n].get("revision"))
                if st != "READY":
                    bad.append(f"{n} rev {d[n].get('revision')} is {st}")
            report(f"every {a.dst} deployment is READY", not bad, "; ".join(bad))
        extra = sorted(set(d) - set(s))
        if extra:
            print(f"  note  only in {a.dst} (not an error): {', '.join(extra)}")

    print("target servers")
    ts, td = (set(names(api, f"/v1/organizations/{a.org}/environments/{e}/targetservers", "targetServers")) for e in (a.src, a.dst))
    report(f"{len(ts)} in {a.src}, {len(td)} in {a.dst}", ts <= td, ", ".join(sorted(ts - td)))

    print("key value maps")
    ks, kd = (set(names(api, f"/v1/organizations/{a.org}/environments/{e}/keyvaluemaps", "keyValueMaps")) for e in (a.src, a.dst))
    report(f"{len(ks)} in {a.src}, {len(kd)} in {a.dst}", ks <= kd, ", ".join(sorted(ks - kd)))
    short = []
    for k in sorted(ks & kd):
        cs, cd = entry_count(api, a.org, a.src, k), entry_count(api, a.org, a.dst, k)
        if cs != cd:
            short.append(f"{k} ({a.src} {cs}, {a.dst} {cd})")
    report("entry counts match", not short, "; ".join(short))

    print()
    print("Everything matches." if not problems else f"{problems} difference(s) found.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
