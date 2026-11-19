#!/usr/bin/env bash
# Tests for developer/app/credential/product write verbs (all platforms).
. "$(dirname "$0")/lib.sh"

ORGP='/v1/organizations/org1'
body() { grep '^body:' "$FAKE_CURL_LOG"; }

test_developer_create_and_delete() {
  use_x
  route POST "$ORGP/developers\$" 201 '{"email":"a@b.com"}'
  route DELETE "$ORGP/developers/a%40b.com\$" 200 '{}'
  run "$APIGEE" developer create a@b.com --first Ann --last Lee
  assert_status "needs confirmation" 1
  run "$APIGEE" --yes developer create a@b.com --first Ann --last Lee
  assert_status "create" 0
  assert_contains "body" "$(body)" '"email":"a@b.com"'
  assert_contains "names" "$(body)" '"firstName":"Ann"'
  run "$APIGEE" --yes developer delete a@b.com
  assert_status "delete" 0
  assert_contains "request" "$(cat "$FAKE_CURL_LOG")" "=== DELETE https://apigee.googleapis.com/v1/organizations/org1/developers/a%40b.com"
}

test_developer_create_defaults_names_from_email_and_edge_username() {
  use_edge
  run "$APIGEE" --yes developer create a@b.com
  assert_status "ok" 0
  assert_contains "user name" "$(body)" '"userName":"a"'
}

test_app_create_with_products_and_callback() {
  use_x
  route POST "$ORGP/developers/a%40b.com/apps\$" 201 '{"name":"app1"}'
  run "$APIGEE" --yes app create --developer a@b.com app1 --product p1 --product p2 --callback https://x.example.com/cb
  assert_status "ok" 0
  assert_contains "products" "$(body)" '"apiProducts":["p1","p2"]'
  assert_contains "callback" "$(body)" '"callbackUrl":"https://x.example.com/cb"'
  assert_contains "name" "$(body)" '"name":"app1"'
}

test_app_create_from_file_and_delete() {
  use_x
  printf '{"name":"app2","apiProducts":["p9"]}' >"$T/app2.json"
  route POST "$ORGP/developers/a%40b.com/apps\$" 201 '{}'
  route DELETE "$ORGP/developers/a%40b.com/apps/app2\$" 200 '{}'
  run "$APIGEE" --yes app create --developer a@b.com --from-file "$T/app2.json"
  assert_status "from file" 0
  assert_contains "file body" "$(body)" '"name":"app2"'
  run "$APIGEE" --yes app delete --developer a@b.com app2
  assert_status "delete" 0
  run "$APIGEE" app delete --developer a@b.com app2
  assert_status "delete confirms" 1
}

test_app_delete_all_matching_prefix_lists_before_deleting() {
  use_x
  route GET "$ORGP/developers/a%40b.com/apps\$" 200 '{"app":[{"name":"tmp-1"},{"name":"keep"},{"name":"tmp-2"}]}'
  route DELETE "$ORGP/developers/a%40b.com/apps/" 200 '{}'
  run "$APIGEE" --yes app delete --developer a@b.com --prefix tmp-
  assert_status "ok" 0
  local log; log="$(cat "$FAKE_CURL_LOG")"
  assert_contains "first" "$log" "apps/tmp-1"
  assert_contains "second" "$log" "apps/tmp-2"
  assert_not_contains "kept" "$log" "=== DELETE https://apigee.googleapis.com/v1/organizations/org1/developers/a%40b.com/apps/keep"
}

test_credential_list_never_prints_secrets() {
  use_x
  route GET "$ORGP/developers/a%40b.com/apps/app1\$" 200 '{"credentials":[{"consumerKey":"k1","consumerSecret":"sekret","status":"approved"}]}'
  run "$APIGEE" credential list --developer a@b.com app1
  assert_status "ok" 0
  assert_eq "keys" "k1 approved" "$OUT"
}

test_credential_get_redacts_unless_asked() {
  use_x
  route GET "$ORGP/developers/a%40b.com/apps/app1/keys/k1\$" 200 '{"consumerKey":"k1","consumerSecret":"sekret","status":"approved"}'
  run "$APIGEE" credential get --developer a@b.com app1 k1
  assert_not_contains "redacted" "$OUT" "sekret"
  run "$APIGEE" credential get --show-credentials --developer a@b.com app1 k1
  assert_contains "shown" "$OUT" "sekret"
}

test_credential_add_takes_secret_from_environment_not_argv() {
  use_x
  route POST "$ORGP/developers/a%40b.com/apps/app1/keys/create\$" 201 '{"consumerKey":"k9"}'
  route POST "$ORGP/developers/a%40b.com/apps/app1/keys/k9\$" 200 '{}'
  APIGEE_CONSUMER_SECRET=topsecret run "$APIGEE" --yes credential add --developer a@b.com app1 --key k9 --product p1
  assert_status "ok" 0
  assert_contains "key" "$(body)" '"consumerKey":"k9"'
  assert_not_contains "secret not in argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "topsecret"
  assert_contains "products set" "$(body)" '"apiProducts":["p1"]'
  run "$APIGEE" --yes credential add --developer a@b.com app1 --key k8 --secret topsecret
  assert_status "no --secret flag" 1
}

test_credential_set_products_and_delete() {
  use_x
  route POST "$ORGP/developers/a%40b.com/apps/app1/keys/k1\$" 200 '{}'
  route DELETE "$ORGP/developers/a%40b.com/apps/app1/keys/k1\$" 200 '{}'
  run "$APIGEE" --yes credential set-products --developer a@b.com app1 k1 p1 p2
  assert_status "set" 0
  assert_contains "body" "$(body)" '"apiProducts":["p1","p2"]'
  run "$APIGEE" --yes credential delete --developer a@b.com app1 k1
  assert_status "delete" 0
}

test_product_create_update_delete() {
  use_x
  route POST "$ORGP/apiproducts\$" 201 '{}'
  route DELETE "$ORGP/apiproducts/p1\$" 200 '{}'
  run "$APIGEE" --yes product create p1 --proxy a --proxy b --environment dev --approval auto --display-name "P One"
  assert_status "create" 0
  assert_contains "proxies" "$(body)" '"proxies":["a","b"]'
  assert_contains "envs" "$(body)" '"environments":["dev"]'
  assert_contains "approval" "$(body)" '"approvalType":"auto"'
  assert_contains "display" "$(body)" '"displayName":"P One"'
  run "$APIGEE" --yes product delete p1
  assert_status "delete" 0
}

test_product_attach_and_detach_proxy_update_the_list() {
  use_x
  route GET "$ORGP/apiproducts/p1\$" 200 '{"name":"p1","proxies":["a"],"environments":["dev"]}'
  route PUT "$ORGP/apiproducts/p1\$" 200 '{}'
  run "$APIGEE" --yes product attach-proxy p1 b
  assert_status "attach" 0
  assert_contains "list" "$(body)" '"proxies":["a","b"]'
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes product detach-proxy p1 a
  assert_status "detach" 0
  assert_contains "list" "$(body)" '"proxies":[]'
}

test_product_proxies_and_find() {
  use_x
  route GET "$ORGP/apiproducts\$" 200 '{"apiProduct":[{"name":"p1"},{"name":"p2"}]}'
  route GET "$ORGP/apiproducts/p1\$" 200 '{"name":"p1","proxies":["a","b"]}'
  route GET "$ORGP/apiproducts/p2\$" 200 '{"name":"p2","proxies":["b"]}'
  run "$APIGEE" product proxies p1
  assert_eq "proxies" "a
b" "$OUT"
  run "$APIGEE" product find --proxy b
  assert_eq "find" "p1
p2" "$OUT"
  run "$APIGEE" product find --proxy a
  assert_eq "find a" "p1" "$OUT"
}

run_tests
