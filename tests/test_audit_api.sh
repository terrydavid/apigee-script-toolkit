#!/usr/bin/env bash
# audit (orphan finder) and raw command.
. "$(dirname "$0")/lib.sh"

test_audit_products_finds_missing_proxies() {
  use_x
  route GET '/organizations/org1/apis$' 200 '{"proxies":[{"name":"p1"}]}'
  route GET '/organizations/org1/apiproducts$' 200 '{"apiProduct":[{"name":"prodA"},{"name":"prodB"}]}'
  route GET '/apiproducts/prodA$' 200 '{"name":"prodA","proxies":["p1"]}'
  route GET '/apiproducts/prodB$' 200 '{"name":"prodB","proxies":["p1","gone"]}'
  run "$APIGEE" audit products
  assert_status "exit 1 when broken" 1
  assert_contains "broken" "$OUT" "prodB gone"
  assert_not_contains "healthy product" "$OUT" "prodA"
}

test_audit_products_clean_exits_zero() {
  use_x
  route GET '/organizations/org1/apis$' 200 '{"proxies":[{"name":"p1"}]}'
  route GET '/organizations/org1/apiproducts$' 200 '{"apiProduct":[{"name":"prodA"}]}'
  route GET '/apiproducts/prodA$' 200 '{"name":"prodA","proxies":["p1"]}'
  run "$APIGEE" audit products
  assert_status "clean" 0
}

test_audit_apps_finds_missing_products() {
  use_x
  route GET '/organizations/org1/apiproducts$' 200 '{"apiProduct":[{"name":"prodA"}]}'
  route GET 'apps\?expand=true' 200 '{"app":[{"name":"app1","developerId":"d1","credentials":[{"apiProducts":[{"apiproduct":"prodA"},{"apiproduct":"nope"}]}]}]}'
  run "$APIGEE" audit apps
  assert_status "broken" 1
  assert_contains "finding" "$OUT" "app1 nope"
  assert_not_contains "ok product" "$OUT" "app1 prodA"
}

test_audit_unknown_verb() {
  use_x
  run "$APIGEE" audit bogus
  assert_status "unknown" 1
}

test_api_get_and_write() {
  use_x
  route GET '/organizations/org1/foo$' 200 '{"ok":true}'
  run "$APIGEE" raw GET /organizations/org1/foo
  assert_status "get" 0
  assert_contains "body" "$OUT" '"ok": true'
  run "$APIGEE" raw POST /organizations/org1/foo --json '{"a":1}'
  assert_status "write needs yes" 1
  assert_eq "nothing sent" "" "$(grep '^=== POST' "$FAKE_CURL_LOG")"
  run "$APIGEE" --yes raw POST /organizations/org1/foo --json '{"a":1}'
  assert_status "write" 0
  assert_contains "sent" "$(curl_log)" '"a":1'
}

test_api_rejects_absolute_urls() {
  use_x
  run "$APIGEE" raw GET https://evil.example.com/x
  assert_status "refused" 1
  assert_eq "nothing sent" "" "$(grep '^=== GET' "$FAKE_CURL_LOG")"
}

test_raw_wait_polls_the_operation() {
  use_x
  export APIGEE_WAIT_INTERVAL=0
  route POST '/organizations/org1/instances$' 200 '{"name":"organizations/org1/operations/op9","done":false}'
  route GET '/operations/op9$' 200 '{"name":"organizations/org1/operations/op9","done":true}'
  run "$APIGEE" --yes raw POST /organizations/org1/instances --json '{"name":"i"}' --wait
  assert_status "wait ok" 0
  assert_contains "polled" "$(curl_log)" "=== GET https://apigee.googleapis.com/v1/organizations/org1/operations/op9"
}

test_raw_wait_fails_when_the_operation_errors() {
  use_x
  export APIGEE_WAIT_INTERVAL=0
  route POST '/organizations/org1/instances$' 200 '{"name":"organizations/org1/operations/op9","done":false}'
  route GET '/operations/op9$' 200 '{"name":"organizations/org1/operations/op9","done":true,"error":{"message":"quota exceeded"}}'
  run "$APIGEE" --yes raw POST /organizations/org1/instances --json '{"name":"i"}' --wait
  assert_status "wait fails" 1
  assert_contains "message" "$ERR" "quota exceeded"
}

run_tests
