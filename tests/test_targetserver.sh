#!/usr/bin/env bash
# Target server create/update/delete/list/get.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TS='/organizations/org1/environments/test/targetservers'

# The request body (pretty-printed, so it spans several log lines).
logged_body() { sed -n '/^body: /,$p' "$FAKE_CURL_LOG" | sed '1s/^body: //'; }

test_list_sorted_names() {
  use_x
  route GET "$TS\$" 200 '["zeta","alpha"]'
  run "$APIGEE" target-server list
  assert_status "list" 0
  assert_eq "sorted" "alpha
zeta" "$OUT"
}

test_get_pretty_prints() {
  use_x
  route GET "$TS/ts1\$" 200 '{"name":"ts1","host":"h","port":443}'
  run "$APIGEE" target-server get ts1
  assert_status "get" 0
  assert_eq "host" "h" "$(printf '%s' "$OUT" | jq -r .host)"
}

test_get_requires_name() {
  use_x
  run "$APIGEE" target-server get
  assert_status "missing name" 1
  assert_contains "msg" "$ERR" "missing NAME"
}

test_create_builds_body() {
  use_x
  run "$APIGEE" --yes target-server create ts1 --host backend.example.com --port 8443 --ssl
  assert_status "create" 0
  local body
  body="$(logged_body)"
  assert_eq "name" "ts1" "$(printf '%s' "$body" | jq -r .name)"
  assert_eq "host" "backend.example.com" "$(printf '%s' "$body" | jq -r .host)"
  assert_eq "port is numeric" "number" "$(printf '%s' "$body" | jq -r '.port | type')"
  assert_eq "enabled default" "true" "$(printf '%s' "$body" | jq -r .isEnabled)"
  assert_eq "ssl" "true" "$(printf '%s' "$body" | jq -r .sSLInfo.enabled)"
  assert_contains "POST" "$(curl_log)" "=== POST https://apigee.googleapis.com/v1$TS"
}

test_create_requires_host_and_port() {
  use_x
  run "$APIGEE" --yes target-server create ts1 --host h
  assert_status "no port" 1
  assert_contains "msg" "$ERR" "needs --host and --port"
}

test_create_rejects_non_numeric_port() {
  use_x
  run "$APIGEE" --yes target-server create ts1 --host h --port abc
  assert_status "bad port" 1
  assert_contains "msg" "$ERR" "--port must be numeric"
}

test_protocol_is_x_only() {
  use_edge
  run "$APIGEE" --yes target-server create ts1 --host h --port 80 --protocol GRPC
  assert_status "edge protocol" 1
}

test_update_merges_with_current() {
  use_x
  route GET "$TS/ts1\$" 200 '{"name":"ts1","host":"old","port":80,"isEnabled":true}'
  run "$APIGEE" --yes target-server update ts1 --port 9090 --disabled
  assert_status "update" 0
  local body
  body="$(logged_body)"
  assert_eq "host kept" "old" "$(printf '%s' "$body" | jq -r .host)"
  assert_eq "port changed" "9090" "$(printf '%s' "$body" | jq -r .port)"
  assert_eq "disabled" "false" "$(printf '%s' "$body" | jq -r .isEnabled)"
  assert_contains "PUT" "$(curl_log)" "=== PUT https://apigee.googleapis.com/v1$TS/ts1"
}

test_create_from_file() {
  use_x
  printf '{"name":"f1","host":"fh","port":1}' >"$T/ts.json"
  run "$APIGEE" --yes target-server create f1 --file "$T/ts.json"
  assert_status "create --file" 0
  assert_contains "body from file" "$(curl_log)" 'body: {"name":"f1","host":"fh","port":1}'
  run "$APIGEE" --yes target-server create f1 --file "$T/nope.json"
  assert_status "missing file" 1
}

test_delete_sends_delete() {
  use_x
  run "$APIGEE" --yes target-server delete ts1
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE https://apigee.googleapis.com/v1$TS/ts1"
}

test_unknown_option_rejected() {
  use_x
  run "$APIGEE" --yes target-server create ts1 --bogus
  assert_status "unknown option" 1
  assert_contains "msg" "$ERR" "unknown option --bogus"
}

run_tests
