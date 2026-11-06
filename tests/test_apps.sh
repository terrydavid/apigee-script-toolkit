#!/usr/bin/env bash
# Developer app approval.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

apps_routes() {
  route GET '/organizations/org1/developers$' 200 '["d1@example.com"]'
  route GET '/developers/d1%40example.com/apps\?expand=true$' 200 "$1"
}

test_approve_all_pending_skips_revoked_apps() {
  use_x
  apps_routes '{"app":[{"name":"app-p","status":"Pending"},{"name":"app-r","status":"revoked"},{"name":"app-a","status":"approved"},{"name":"app-p2","status":"pending"}]}'
  run "$APIGEE" --yes app approve --all-pending
  assert_status "approve" 0
  local posts
  posts="$(grep '^=== POST' "$FAKE_CURL_LOG" | sed 's#.*/apps/##')"
  assert_eq "only pending apps approved" "app-p?action=approve
app-p2?action=approve" "$posts"
  assert_contains "revoked reported" "$ERR" "skipping app app-r (d1@example.com): status is 'revoked', not 'pending'"
  assert_not_contains "approved not reported" "$ERR" "app-a"
}

test_approve_all_pending_with_only_revoked_apps_sends_nothing() {
  use_edge
  apps_routes '[{"name":"app-r","status":"REVOKED"},{"name":"app-a","status":"approved"}]'
  run "$APIGEE" --yes app approve --all-pending
  assert_status "approve" 0
  assert_contains "nothing pending" "$ERR" "no pending apps"
  assert_contains "revoked reported" "$ERR" "skipping app app-r"
  assert_eq "no writes" "" "$(grep '^=== POST' "$FAKE_CURL_LOG")"
}

test_approve_all_pending_dry_run_lists_only_pending() {
  use_x
  apps_routes '{"app":[{"name":"app-p","status":"pending"},{"name":"app-r","status":"revoked"}]}'
  run "$APIGEE" --dry-run app approve --all-pending
  assert_status "dry-run" 0
  assert_contains "plan" "$ERR" "d1@example.com app-p"
  assert_contains "dry-run post" "$OUT" "DRY-RUN: POST https://apigee.googleapis.com/v1/organizations/org1/developers/d1%40example.com/apps/app-p?action=approve"
  assert_not_contains "revoked not planned" "$OUT" "app-r"
}

run_tests
