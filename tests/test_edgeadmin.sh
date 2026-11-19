#!/usr/bin/env bash
# Edge/OPDK write verbs: cache create/delete/get, virtualhost create/update/delete,
# keystore create/delete/upload-cert.
. "$(dirname "$0")/lib.sh"

ENVP='/organizations/org1/environments/test'

test_cache_create_defaults_and_options() {
  use_edge
  run "$APIGEE" --yes cache create c1 --timeout 600 --max-elements 500 --description "my cache"
  assert_status "create" 0
  assert_contains "POST" "$(curl_log)" "=== POST"
  assert_contains "url" "$(curl_log)" "$ENVP/caches"
  assert_contains "name" "$(curl_log)" '"name":"c1"'
  assert_contains "timeout" "$(curl_log)" '"timeoutInSec":{"value":"600"}'
  assert_contains "max" "$(curl_log)" '"maxElementsInMemory":500'
  assert_contains "desc" "$(curl_log)" '"description":"my cache"'
}

test_cache_create_requires_confirmation_and_edge() {
  use_edge
  run "$APIGEE" cache create c1
  assert_status "no yes" 1
  assert_eq "no POST" "" "$(grep '^=== POST' "$FAKE_CURL_LOG")"
  use_x
  run "$APIGEE" --yes cache create c1
  assert_status "x refused" 1
}

test_cache_get_and_delete() {
  use_edge
  route GET "$ENVP/caches/c1\$" 200 '{"name":"c1","overflowToDisk":false}'
  run "$APIGEE" cache get c1
  assert_status "get" 0
  assert_contains "json" "$OUT" '"name": "c1"'
  run "$APIGEE" --yes cache delete c1
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
  assert_contains "url" "$(curl_log)" "$ENVP/caches/c1"
}

test_virtualhost_create_plain() {
  use_edge
  run "$APIGEE" --yes virtualhost create vh1 --port 9001 --alias a.example.com --alias b.example.com
  assert_status "create" 0
  assert_contains "url" "$(curl_log)" "$ENVP/virtualhosts"
  assert_contains "name" "$(curl_log)" '"name":"vh1"'
  assert_contains "aliases" "$(curl_log)" '"hostAliases":["a.example.com","b.example.com"]'
  assert_contains "port" "$(curl_log)" '"port":"9001"'
}

test_virtualhost_create_ssl_and_from_file() {
  use_edge
  run "$APIGEE" --yes virtualhost create vh2 --port 443 --alias s.example.com --keystore ks1 --key-alias k1
  assert_status "ssl" 0
  assert_contains "ssl" "$(curl_log)" '"sSLInfo":{"enabled":true'
  assert_contains "ks" "$(curl_log)" '"keyStore":"ks1"'
  assert_contains "alias" "$(curl_log)" '"keyAlias":"k1"'
  printf '{"name":"vh3","hostAliases":["x"],"port":"80"}' >"$T/vh.json"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes virtualhost create --from-file "$T/vh.json"
  assert_status "file" 0
  assert_contains "file body" "$(curl_log)" '"name":"vh3"'
}

test_virtualhost_update_and_delete() {
  use_edge
  route GET "$ENVP/virtualhosts/vh1\$" 200 '{"name":"vh1","hostAliases":["old"],"port":"80","interfaces":[]}'
  run "$APIGEE" --yes virtualhost update vh1 --alias new.example.com --port 8080
  assert_status "update" 0
  assert_contains "PUT" "$(curl_log)" "=== PUT"
  assert_contains "aliases" "$(curl_log)" '"hostAliases":["new.example.com"]'
  assert_contains "port" "$(curl_log)" '"port":"8080"'
  run "$APIGEE" --yes virtualhost delete vh1
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
}

test_virtualhost_write_needs_confirmation() {
  use_edge
  run "$APIGEE" virtualhost delete vh1
  assert_status "no yes" 1
  assert_eq "no DELETE" "" "$(grep '^=== DELETE' "$FAKE_CURL_LOG")"
}

test_keystore_create_and_delete() {
  use_edge
  run "$APIGEE" --yes keystore create ks1
  assert_status "create" 0
  assert_contains "url" "$(curl_log)" "$ENVP/keystores"
  assert_contains "body" "$(curl_log)" '"name":"ks1"'
  run "$APIGEE" --yes keystore delete ks1
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
}

test_keystore_upload_cert_keeps_password_off_argv() {
  use_edge
  printf 'KEY' >"$T/k.pem"; printf 'CERT' >"$T/c.pem"
  APIGEE_KEY_PASSWORD=s3cret run "$APIGEE" --yes keystore upload-cert ks1 --alias k1 --key-file "$T/k.pem" --cert-file "$T/c.pem"
  assert_status "upload" 0
  assert_contains "url" "$(curl_log)" "keystores/ks1/aliases?alias=k1&format=keycertfile"
  assert_contains "keyfile" "$(curl_log)" "keyFile=@$T/k.pem"
  assert_contains "certfile" "$(curl_log)" "certFile=@$T/c.pem"
  assert_not_contains "no secret in argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "s3cret"
  assert_contains "secret via config" "$(grep '^config:' "$FAKE_CURL_LOG")" "s3cret"
}

test_keystore_upload_cert_cert_only_for_truststore() {
  use_edge
  printf 'CERT' >"$T/c.pem"
  run "$APIGEE" --yes truststore upload-cert ts1 --alias c1 --cert-file "$T/c.pem"
  assert_status "cert only" 0
  assert_contains "url" "$(curl_log)" "keystores/ts1/aliases?alias=c1&format=pem"
  assert_not_contains "no key" "$(curl_log)" "keyFile"
}

test_keystore_upload_refuses_password_flag() {
  use_edge
  run "$APIGEE" --yes keystore upload-cert ks1 --alias k --key-file /dev/null --cert-file /dev/null --password x
  assert_status "flag refused" 1
}

run_tests
