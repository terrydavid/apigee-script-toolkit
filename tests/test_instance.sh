#!/usr/bin/env bash
# Tests for 'apigee instance'.
. "$(dirname "$0")/lib.sh"

test_instance_list() {
  use_x
  route GET '/organizations/org1/instances$' 200 '{"instances":[{"name":"eval-instance"},{"name":"prod-1"}]}'
  run "$APIGEE" instance list
  assert_status "ok" 0
  assert_eq "names" "eval-instance
prod-1" "$OUT"
}

test_instance_attachments_shows_environments() {
  use_x
  route GET '/organizations/org1/instances/eval-instance/attachments$' 200 '{"attachments":[{"name":"a1","environment":"dev"}]}'
  run "$APIGEE" instance attachments eval-instance
  assert_status "ok" 0
  assert_contains "environment" "$OUT" '"environment": "dev"'
}

test_instance_attach_posts_the_environment() {
  use_x
  route POST '/organizations/org1/instances/eval-instance/attachments$' 200 '{"name":"operations/op1","done":false}'
  run "$APIGEE" --yes instance attach eval-instance
  assert_status "ok" 0
  assert_contains "request" "$(cat "$FAKE_CURL_LOG")" "=== POST https://apigee.googleapis.com/v1/organizations/org1/instances/eval-instance/attachments"
  assert_contains "body" "$(cat "$FAKE_CURL_LOG")" '{"environment":"test"}'
}

test_instance_attach_dry_run_and_confirmation() {
  use_x
  run "$APIGEE" -n instance attach eval-instance
  assert_status "dry run" 0
  assert_contains "shown" "$ERR$OUT" "DRY-RUN: POST"
  assert_eq "nothing sent" "" "$(grep '=== POST' "$FAKE_CURL_LOG")"
  run "$APIGEE" instance attach eval-instance
  assert_status "needs confirmation without a terminal" 1
}

test_instance_is_x_only_and_validates_input() {
  use_edge
  run "$APIGEE" instance list
  assert_status "edge refused" 1
  assert_contains "reason" "$ERR" "not supported on"
  use_x
  run "$APIGEE" instance attach
  assert_status "missing instance" 1
  assert_contains "msg" "$ERR" "missing INSTANCE"
}

run_tests
