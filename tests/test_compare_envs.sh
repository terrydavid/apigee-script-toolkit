#!/usr/bin/env bash
# Tests for tools/compare_envs.py against a small local fake of the Apigee API.
. "$(dirname "$0")/lib.sh"

COMPARE="$ROOT/tools/compare_envs.py"
command -v python3 >/dev/null || { echo "python3 missing; skipping"; exit 0; }

# start_api ROUTES_JSON: serve {"path?query": body} on a free port; sets PORT, SERVER_PID.
start_api() {
  cat >"$T/server.py" <<'PY'
import http.server, json, sys
routes = json.load(open(sys.argv[1]))
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = routes.get(self.path)
        if body is None:
            self.send_response(404); self.end_headers(); self.wfile.write(b'{"error":"no route"}'); return
        data = json.dumps(body).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(data)
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
s.serve_forever()
PY
  python3 "$T/server.py" "$1" >"$T/port" &
  SERVER_PID=$!
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 20 20; do [[ -s "$T/port" ]] && break; sleep 0.2; done
  PORT="$(cat "$T/port")"
}
stop_api() { kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; }

E=/v1/organizations/o1/environments
make_routes() { # $1 = dst proxy revision for p1, $2 = state of p2, $3 = dst kvm entries
  python3 - "$T/routes.json" "$1" "$2" "$3" <<'PY'
import json, sys
out, p1rev, p2state, kvmn = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
E = "/v1/organizations/o1/environments"
dep = lambda n, r: {"apiProxy": n, "revision": r, "serviceAccount": "sa@x"}
r = {
  f"{E}/dev/deployments?sharedFlows=true": {"deployments": [dep("sf1", "1")]},
  f"{E}/tst/deployments?sharedFlows=true": {"deployments": [dep("sf1", "1")]},
  f"{E}/dev/deployments": {"deployments": [dep("p1", "3"), dep("p2", "5")]},
  f"{E}/tst/deployments": {"deployments": [dep("p1", p1rev)] + ([dep("p2", "5")] if p2state != "MISSING" else [])},
  f"{E}/tst/sharedflows/sf1/revisions/1/deployments": {"state": "READY"},
  f"{E}/tst/apis/p1/revisions/{p1rev}/deployments": {"state": "READY"},
  f"{E}/dev/apis/p2/revisions/5/deployments": {"state": "ERROR" if p2state == "ERRORBOTH" else "READY"},
  f"{E}/tst/apis/p2/revisions/5/deployments": ({"state": "ERROR", "errors": [{"message": "environment is not attached to an instance"}]} if p2state in ("ERROR", "ERRORBOTH") else {"state": p2state}),
  f"{E}/dev/targetservers": ["ts1", "ts2"],
  f"{E}/tst/targetservers": ["ts1", "ts2"],
  f"{E}/dev/keyvaluemaps": ["kv1"],
  f"{E}/tst/keyvaluemaps": ["kv1"],
  f"{E}/dev/keyvaluemaps/kv1/entries?pageSize=100": {"keyValueEntries": [{"name": "a"}, {"name": "b"}]},
  f"{E}/tst/keyvaluemaps/kv1/entries?pageSize=100": {"keyValueEntries": [{"name": str(i)} for i in range(kvmn)]},
}
json.dump(r, open(out, "w"))
PY
}

test_compare_matching_environments() {
  make_routes 3 READY 2
  start_api "$T/routes.json"
  APIGEE_TOKEN=t run python3 "$COMPARE" --org o1 --base-url "http://127.0.0.1:$PORT" dev tst
  stop_api
  assert_status "matches" 0
  assert_contains "verdict" "$OUT" "Everything matches."
  assert_contains "ready check" "$OUT" "every tst deployment is READY"
}

test_compare_reports_each_kind_of_difference() {
  make_routes 4 ERROR 1
  start_api "$T/routes.json"
  APIGEE_TOKEN=t run python3 "$COMPARE" --org o1 --base-url "http://127.0.0.1:$PORT" dev tst
  stop_api
  assert_status "differences" 1
  assert_contains "revision" "$OUT" "p1 (dev 3, tst 4)"
  assert_contains "state" "$OUT" "p2 rev 5 is ERROR (in dev: READY)"
  assert_contains "reason from Apigee" "$OUT" "reason x1: environment is not attached to an instance"
  assert_contains "count" "$OUT" "1 of 2 not READY"
  assert_contains "kvm count" "$OUT" "kv1 (dev 2, tst 1)"
  assert_contains "verdict" "$OUT" "difference(s) found."
}

test_compare_error_present_in_source_too_is_not_a_difference() {
  make_routes 3 ERRORBOTH 2
  start_api "$T/routes.json"
  APIGEE_TOKEN=t run python3 "$COMPARE" --org o1 --base-url "http://127.0.0.1:$PORT" dev tst
  stop_api
  assert_status "matches" 0
  assert_contains "inherited" "$OUT" "p2 rev 5 is ERROR in dev too"
  assert_contains "verdict" "$OUT" "Everything matches."
}

test_compare_reports_a_missing_deployment() {
  make_routes 3 MISSING 2
  start_api "$T/routes.json"
  APIGEE_TOKEN=t run python3 "$COMPARE" --org o1 --base-url "http://127.0.0.1:$PORT" --no-state dev tst
  stop_api
  assert_status "differences" 1
  assert_contains "missing" "$OUT" "not deployed in tst: p2"
}

test_compare_needs_a_token() {
  FAKE_GCLOUD_FAIL="not logged in" APIGEE_TOKEN= run python3 "$COMPARE" --org o1 --base-url http://127.0.0.1:1 dev tst
  assert_status "no token" 2
  assert_contains "says why" "$ERR" "set APIGEE_TOKEN or log in with gcloud"
}

test_compare_unreachable_api_is_an_error() {
  APIGEE_TOKEN=t run python3 "$COMPARE" --org o1 --base-url http://127.0.0.1:1 dev tst
  assert_status "request error" 2
}

run_tests
