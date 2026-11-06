#!/usr/bin/env bash
# Dry-run and confirmation behaviour of mutating verbs.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

test_dry_run_prints_request_and_sends_nothing() {
  use_x
  run "$APIGEE" --dry-run kvm delete map1
  assert_status "dry-run" 0
  assert_contains "printed" "$OUT" "DRY-RUN: DELETE https://apigee.googleapis.com/v1/organizations/org1/environments/test/keyvaluemaps/map1"
  assert_contains "auth described" "$OUT" "Authorization: Bearer <redacted>"
  assert_eq "no request" "" "$(curl_log)"
}

test_dry_run_edge_describes_basic_auth_without_secret() {
  use_edge
  run "$APIGEE" -n target-server delete ts1
  assert_contains "printed" "$OUT" "DRY-RUN: DELETE https://api.enterprise.apigee.com/v1/organizations/org1/environments/test/targetservers/ts1"
  assert_contains "basic" "$OUT" "Authorization: Basic <redacted> (user user@example.com)"
  assert_not_contains "no password" "$OUT" "s3cr3t-pass"
}

test_dry_run_body_is_summarised_not_printed() {
  use_x
  run "$APIGEE" --dry-run kvm put map1 apikey --value-stdin
  assert_status "put" 0
  assert_contains "post" "$OUT" "DRY-RUN: POST https://apigee.googleapis.com/v1/organizations/org1/environments/test/keyvaluemaps/map1/entries"
  assert_contains "size only" "$OUT" "body:"
  assert_contains "bytes" "$OUT" "bytes"
}

test_dry_run_still_reads_to_plan() {
  use_x
  route GET '/apis/p1/revisions$' 200 '["1","2","3"]'
  run "$APIGEE" --dry-run proxy deploy p1 --latest
  assert_status "deploy" 0
  assert_contains "read executed" "$(curl_log)" "=== GET https://apigee.googleapis.com/v1/organizations/org1/apis/p1/revisions"
  assert_contains "write printed" "$OUT" "DRY-RUN: POST https://apigee.googleapis.com/v1/organizations/org1/environments/test/apis/p1/revisions/3/deployments?override=true"
  assert_not_contains "write not sent" "$(curl_log)" "=== POST"
}

test_mutation_refused_without_tty_or_yes() {
  use_x
  run "$APIGEE" kvm delete map1
  assert_status "refused" 1
  assert_contains "message" "$ERR" "re-run with --yes"
  assert_eq "nothing sent" "" "$(grep '^===' "$FAKE_CURL_LOG")"
}

test_yes_flag_allows_mutation() {
  use_x
  run "$APIGEE" kvm delete map1 --yes
  assert_status "deleted" 0
  assert_contains "sent" "$(curl_log)" "=== DELETE https://apigee.googleapis.com/v1/organizations/org1/environments/test/keyvaluemaps/map1"
}

test_every_mutating_verb_requires_confirmation() {
  use_x
  local zip="$T/b.zip"
  printf 'PK' >"$zip"
  route GET '/apis/p1/revisions$' 200 '["1","2"]'
  route GET '/deployments$' 200 '{}'
  local cmd
  while IFS= read -r cmd; do
    : >"$FAKE_CURL_LOG"
    # shellcheck disable=SC2086
    run "$APIGEE" $cmd
    assert_status "$cmd" 1
    assert_contains "$cmd" "$ERR" "re-run with --yes"
    assert_not_contains "$cmd sent a write" "$(grep '^===' "$FAKE_CURL_LOG")" "=== DELETE"
    assert_not_contains "$cmd sent a write" "$(grep '^===' "$FAKE_CURL_LOG" | grep -v oauth)" "=== POST"
    assert_not_contains "$cmd sent a write" "$(grep '^===' "$FAKE_CURL_LOG")" "=== PUT"
  done <<EOF
kvm create m1
kvm delete m1 k1
kvm put m1 k1 v1
target-server create ts1 --host h.example.com --port 443
target-server delete ts1
proxy deploy p1 2
proxy undeploy p1 2
proxy delete-revision p1 1
proxy import p1 $zip
sharedflow delete-revision p1 1
app approve --developer d@example.com app1
app revoke --developer d@example.com app1
EOF
}

test_api_error_reports_status_and_fails() {
  use_x
  route GET '/apis/missing/revisions$' 404 '{"error":{"code":404,"message":"not found"}}'
  run "$APIGEE" proxy revisions missing
  assert_status "error" 1
  assert_contains "http status" "$ERR" "HTTP 404"
  assert_contains "body" "$ERR" "not found"
}

run_tests
