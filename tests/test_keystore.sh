#!/usr/bin/env bash
# Keystore / truststore read-only views.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

KS='/organizations/org1/environments/test/keystores'

test_keystore_list_sorted() {
  use_x
  route GET "$KS\$" 200 '["b-store","a-store"]'
  run "$APIGEE" keystore list
  assert_status "list" 0
  assert_eq "sorted" "a-store
b-store" "$OUT"
}

test_keystore_get_does_not_fetch_aliases() {
  use_x
  route GET "$KS/ks1\$" 200 '{"name":"ks1","aliases":["a1"]}'
  run "$APIGEE" keystore get ks1
  assert_status "get" 0
  assert_eq "one request" "1" "$(grep -c '^=== GET' "$FAKE_CURL_LOG")"
}

test_truststore_get_fetches_each_alias() {
  use_x
  route GET "$KS/ts1\$" 200 '{"name":"ts1","aliases":["a1","a2"]}'
  route GET "$KS/ts1/aliases/a1\$" 200 '{"alias":"a1"}'
  route GET "$KS/ts1/aliases/a2\$" 200 '{"alias":"a2"}'
  run "$APIGEE" truststore get ts1
  assert_status "get" 0
  assert_contains "alias a1" "$(curl_log)" "/keystores/ts1/aliases/a1"
  assert_contains "alias a2" "$(curl_log)" "/keystores/ts1/aliases/a2"
}

test_keystore_get_requires_name() {
  use_x
  run "$APIGEE" keystore get
  assert_status "missing name" 1
  assert_contains "msg" "$ERR" "missing NAME"
}

test_keystore_works_on_edge() {
  use_edge
  route GET "$KS\$" 200 '["k1"]'
  run "$APIGEE" keystore list
  assert_status "edge list" 0
  assert_eq "k1" "k1" "$OUT"
}

run_tests
