#!/usr/bin/env bash
# Developer / product / app export+import, credential redaction, env import.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

ORGP=/organizations/org1
APP_JSON='{"name":"app1","appId":"id-1","attributes":[{"name":"tier","value":"gold"}],"callbackUrl":"https://cb","credentials":[{"consumerKey":"KEY123","consumerSecret":"SECRET456","apiProducts":[{"apiproduct":"prod2"},{"apiproduct":"prod1"}]}]}'

mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
posts() { grep '^=== ' "$FAKE_CURL_LOG" | grep -v '=== GET' | sed -e 's/^=== //' -e 's#https://apigee.googleapis.com/v1##'; }

app_routes() {
  route GET "$ORGP/developers\$" 200 '["d1@example.com"]'
  route GET "$ORGP/developers/d1%40example.com/apps\?expand=true\$" 200 "{\"app\":[$APP_JSON]}"
}

# --- credentials switch -----------------------------------------------------

test_app_get_redacts_credentials_by_default() {
  use_x
  route GET "$ORGP/apps/id-1\$" 200 "$APP_JSON"
  run "$APIGEE" app get id-1
  assert_status "get" 0
  assert_not_contains "no key" "$OUT" "KEY123"
  assert_not_contains "no secret" "$OUT" "SECRET456"
  assert_contains "marker" "$OUT" "<redacted>"
  assert_contains "other fields intact" "$OUT" "gold"
}

test_app_get_show_credentials() {
  use_x
  route GET "$ORGP/apps/id-1\$" 200 "$APP_JSON"
  run "$APIGEE" app get --show-credentials id-1
  assert_status "get" 0
  assert_contains "key" "$OUT" "KEY123"
  assert_contains "secret" "$OUT" "SECRET456"
  run "$APIGEE" app get id-1 --show-credentials
  assert_contains "switch after the id" "$OUT" "SECRET456"
}

test_app_get_by_developer_redacts() {
  use_x
  route GET "$ORGP/developers/d1%40example.com/apps/app1\$" 200 "$APP_JSON"
  run "$APIGEE" app get --developer d1@example.com app1
  assert_not_contains "no secret" "$OUT" "SECRET456"
}

# --- export -----------------------------------------------------------------

test_app_export_redacts_and_is_private() {
  use_x
  app_routes
  run "$APIGEE" app export "$T/ex"
  assert_status "export" 0
  local f="$T/ex/apps/d1@example.com/app1.json"
  assert_contains "name" "$(cat "$f")" '"name": "app1"'
  assert_not_contains "no secret in file" "$(cat "$f")" "SECRET456"
  assert_eq "file mode" "600" "$(mode_of "$f")"
  assert_eq "dir mode" "700" "$(mode_of "$T/ex/apps/d1@example.com")"
}

test_app_export_show_credentials_writes_secrets() {
  use_x
  app_routes
  run "$APIGEE" app export "$T/ex" --show-credentials
  assert_status "export" 0
  assert_contains "secret" "$(cat "$T/ex/apps/d1@example.com/app1.json")" "SECRET456"
  assert_contains "warned" "$ERR" "--show-credentials"
  assert_eq "file mode" "600" "$(mode_of "$T/ex/apps/d1@example.com/app1.json")"
}

test_developer_and_product_export() {
  use_x
  route GET "$ORGP/developers\$" 200 '["d1@example.com"]'
  route GET "$ORGP/developers/d1%40example.com\$" 200 '{"email":"d1@example.com","firstName":"D"}'
  route GET "$ORGP/apiproducts\$" 200 '["prod1"]'
  route GET "$ORGP/apiproducts/prod1\$" 200 '{"name":"prod1","approvalType":"auto"}'
  run "$APIGEE" developer export "$T/ex"
  assert_status "dev export" 0
  assert_eq "dev file" "D" "$(jq -r .firstName "$T/ex/developers/d1@example.com.json")"
  run "$APIGEE" product export "$T/ex"
  assert_status "product export" 0
  assert_eq "product file" "auto" "$(jq -r .approvalType "$T/ex/products/prod1.json")"
  assert_eq "dev mode" "600" "$(mode_of "$T/ex/developers/d1@example.com.json")"
}

test_env_export_includes_org_data() {
  use_x
  app_routes
  route GET "$ORGP/developers/d1%40example.com\$" 200 '{"email":"d1@example.com"}'
  route GET "$ORGP/apiproducts\$" 200 '["prod1"]'
  route GET "$ORGP/apiproducts/prod1\$" 200 '{"name":"prod1"}'
  route GET "$ORGP/envgroups\$" 200 '{"environmentGroups":[{"name":"g1"}]}'
  route GET "$ORGP/envgroups/g1\$" 200 '{"name":"g1","hostnames":["a.example.com"]}'
  route GET "$ORGP/environments/test/keystores\$" 200 '["ks1"]'
  route GET "$ORGP/environments/test/keystores/ks1\$" 200 '{"name":"ks1","aliases":[]}'
  run "$APIGEE" env export "$T/snap" --no-bundles --no-kvms
  assert_status "export" 0
  assert_eq "developer" "d1@example.com" "$(jq -r .email "$T/snap/developers/d1@example.com.json")"
  assert_eq "product" "prod1" "$(jq -r .name "$T/snap/products/prod1.json")"
  assert_eq "app" "app1" "$(jq -r .name "$T/snap/apps/d1@example.com/app1.json")"
  assert_eq "envgroup" "g1" "$(jq -r .name "$T/snap/envgroups/g1.json")"
  assert_eq "keystore" "ks1" "$(jq -r .name "$T/snap/keystores/ks1.json")"
  assert_not_contains "secrets redacted" "$(cat "$T/snap/apps/d1@example.com/app1.json")" "SECRET456"
}

test_env_export_opt_outs_and_show_credentials() {
  use_x
  app_routes
  run "$APIGEE" env export "$T/snap" --no-bundles --no-kvms --no-keystores --no-developers --no-products --show-credentials
  assert_status "export" 0
  assert_eq "no developers dir" "no" "$([[ -d $T/snap/developers ]] && echo yes || echo no)"
  assert_eq "no products dir" "no" "$([[ -d $T/snap/products ]] && echo yes || echo no)"
  assert_contains "secret written" "$(cat "$T/snap/apps/d1@example.com/app1.json")" "SECRET456"
}

# --- import -----------------------------------------------------------------

make_export() {
  mkdir -p "$T/in/developers" "$T/in/products" "$T/in/apps/d1@example.com" "$T/in/targetservers" "$T/in/kvms"
  printf '%s' '{"email":"d1@example.com","firstName":"D","developerId":"abc","createdAt":1,"apps":["app1"]}' >"$T/in/developers/d1@example.com.json"
  printf '%s' '{"name":"prod1","approvalType":"auto","createdAt":1,"lastModifiedAt":2}' >"$T/in/products/prod1.json"
  printf '%s' "$1" >"$T/in/apps/d1@example.com/app1.json"
  printf '%s' '{"name":"ts1","host":"h","port":80,"isEnabled":true}' >"$T/in/targetservers/ts1.json"
  printf '%s' '{"name":"m1","encrypted":true,"entries":[{"name":"k","value":"v"}]}' >"$T/in/kvms/m1.json"
}

test_developer_import_strips_readonly_fields_and_skips_existing() {
  use_x
  make_export "$APP_JSON"
  route POST "$ORGP/developers\$" 409 '{"error":{"code":409}}'
  run "$APIGEE" --yes developer import "$T/in"
  assert_status "import" 0
  assert_contains "skipped" "$ERR" "1 already existed (skipped)"
  assert_eq "no PUT" "" "$(grep '^=== PUT' "$FAKE_CURL_LOG")"
  local body
  body="$(sed -n '/^body: /,$p' "$FAKE_CURL_LOG" | tr -d ' \n')"
  assert_not_contains "developerId stripped" "$body" "developerId"
  assert_not_contains "apps stripped" "$body" '"apps"'
  assert_contains "email sent" "$body" "d1@example.com"
}

test_developer_import_overwrite_puts() {
  use_x
  make_export "$APP_JSON"
  route POST "$ORGP/developers\$" 409 '{}'
  run "$APIGEE" --yes developer import "$T/in" --overwrite
  assert_status "import" 0
  assert_contains "updated" "$ERR" "1 updated"
  assert_contains "PUT" "$(posts)" "PUT /organizations/org1/developers/d1%40example.com"
}

test_product_import_creates() {
  use_x
  make_export "$APP_JSON"
  run "$APIGEE" --yes product import "$T/in/products"
  assert_status "import" 0
  assert_contains "created" "$ERR" "1 created"
  assert_not_contains "timestamps stripped" "$(sed -n '/^body: /,$p' "$FAKE_CURL_LOG")" "createdAt"
}

test_import_requires_confirmation() {
  use_x
  make_export "$APP_JSON"
  run "$APIGEE" product import "$T/in"
  assert_status "no tty, no --yes" 1
  assert_eq "nothing sent to Apigee" "" "$(posts | grep -v tokeninfo)"
}

test_import_with_no_files_fails() {
  use_x
  mkdir -p "$T/empty"
  run "$APIGEE" --yes developer import "$T/empty"
  assert_status "empty" 1
  assert_contains "msg" "$ERR" "no developer files"
}

test_app_import_creates_with_products_and_restores_credentials() {
  use_x
  make_export "$APP_JSON"
  route GET "$ORGP/developers/d1%40example.com/apps/app1\$" 200 '{"name":"app1","credentials":[{"consumerKey":"GENERATED","consumerSecret":"x"}]}'
  run "$APIGEE" --yes app import "$T/in"
  assert_status "import" 0
  local p
  p="$(posts)"
  assert_contains "app created" "$p" "POST /organizations/org1/developers/d1%40example.com/apps"
  assert_contains "key restored" "$p" "POST /organizations/org1/developers/d1%40example.com/apps/app1/keys"
  assert_contains "products attached" "$p" "apps/app1/keys/KEY123"
  assert_contains "generated key removed" "$p" "DELETE /organizations/org1/developers/d1%40example.com/apps/app1/keys/GENERATED"
  local log
  log="$(sed -n '/^body: /,$p' "$FAKE_CURL_LOG" | tr -d ' \n')"
  assert_contains "products in create body" "$log" '"apiProducts":["prod1","prod2"]'
  assert_contains "secret sent" "$log" "SECRET456"
}

test_app_import_edge_uses_keys_create() {
  use_edge
  make_export "$APP_JSON"
  route GET "$ORGP/developers/d1%40example.com/apps/app1\$" 200 '{"name":"app1","credentials":[{"consumerKey":"GENERATED"}]}'
  run "$APIGEE" --yes app import "$T/in"
  assert_status "import" 0
  assert_contains "edge key create" "$(posts)" "apps/app1/keys/create"
}

test_app_import_redacted_credentials_are_not_restored() {
  use_x
  make_export '{"name":"app1","credentials":[{"consumerKey":"<redacted>","consumerSecret":"<redacted>","apiProducts":[{"apiproduct":"prod1"}]}]}'
  run "$APIGEE" --yes app import "$T/in"
  assert_status "import" 0
  assert_not_contains "no key calls" "$(posts)" "/keys"
}

test_app_import_needs_developer_directory() {
  use_x
  mkdir -p "$T/flat"
  printf '%s' "$APP_JSON" >"$T/flat/app1.json"
  run "$APIGEE" --yes app import "$T/flat"
  assert_status "bad layout" 1
  assert_contains "msg" "$ERR" "cannot tell the developer"
}

test_env_import_runs_every_step_once_confirmed() {
  use_x
  make_export "$APP_JSON"
  mkdir -p "$T/in/proxies" "$T/in/sharedflows"
  printf 'zipdata' >"$T/in/proxies/p1-rev3.zip"
  printf 'zipdata' >"$T/in/sharedflows/s1-rev1.zip"
  route POST "$ORGP/apis\?action=import" 200 '{"revision":"4"}'
  route POST "$ORGP/sharedflows\?action=import" 200 '{"revision":"2"}'
  route GET "$ORGP/environments/test/keyvaluemaps\$" 200 '[]'
  route GET "$ORGP/developers/d1%40example.com/apps/app1\$" 200 '{"name":"app1","credentials":[]}'
  run "$APIGEE" --yes env import "$T/in" --deploy
  assert_status "import" 0
  local p
  p="$(posts)"
  assert_contains "target server" "$p" "POST /organizations/org1/environments/test/targetservers"
  assert_contains "kvm" "$p" "keyvaluemaps"
  assert_contains "developer" "$p" "POST /organizations/org1/developers"
  assert_contains "product" "$p" "POST /organizations/org1/apiproducts"
  assert_contains "app" "$p" "POST /organizations/org1/developers/d1%40example.com/apps"
  assert_contains "shared flow import" "$p" "sharedflows?action=import&name=s1"
  assert_contains "proxy import" "$p" "apis?action=import&name=p1"
  assert_contains "shared flow deployed" "$p" "sharedflows/s1/revisions/2/deployments"
  assert_contains "proxy deployed" "$p" "apis/p1/revisions/4/deployments"
  local order
  order="$(printf '%s\n' "$p" | grep -n 'sharedflows?action=import\|apis?action=import' | sed 's/:.*import.*name=/ /')"
  assert_eq "shared flows before proxies" "s1 p1" "$(printf '%s' "$order" | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//')"
}

test_env_import_without_deploy_does_not_deploy() {
  use_x
  make_export "$APP_JSON"
  mkdir -p "$T/in/proxies"
  printf 'zipdata' >"$T/in/proxies/p1-rev3.zip"
  route POST "$ORGP/apis\?action=import" 200 '{"revision":"4"}'
  route GET "$ORGP/environments/test/keyvaluemaps\$" 200 '[]'
  route GET "$ORGP/developers/d1%40example.com/apps/app1\$" 200 '{"name":"app1","credentials":[]}'
  run "$APIGEE" --yes env import "$T/in"
  assert_status "import" 0
  assert_not_contains "no deploy" "$(posts)" "deployments"
}

test_env_import_opt_outs() {
  use_x
  make_export "$APP_JSON"
  run "$APIGEE" --yes env import "$T/in" --no-kvms --no-developers --no-products --no-apps --no-bundles
  assert_status "import" 0
  assert_eq "only target servers" "POST /organizations/org1/environments/test/targetservers" "$(posts)"
}

test_env_import_needs_confirmation_and_dir() {
  use_x
  make_export "$APP_JSON"
  run "$APIGEE" env import "$T/in"
  assert_status "no yes" 1
  assert_eq "nothing sent to Apigee" "" "$(posts | grep -v tokeninfo)"
  run "$APIGEE" --yes env import
  assert_contains "missing dir" "$ERR" "missing DIR"
  mkdir -p "$T/none"
  run "$APIGEE" --yes env import "$T/none"
  assert_contains "nothing to import" "$ERR" "nothing to import"
}

test_env_import_dry_run_sends_nothing() {
  use_x
  make_export "$APP_JSON"
  run "$APIGEE" -n env import "$T/in"
  assert_status "dry run" 0
  assert_eq "no writes" "" "$(posts)"
}

test_export_then_import_round_trip() {
  use_x
  app_routes
  route GET "$ORGP/developers/d1%40example.com\$" 200 '{"email":"d1@example.com"}'
  route GET "$ORGP/apiproducts\$" 200 '["prod1"]'
  route GET "$ORGP/apiproducts/prod1\$" 200 '{"name":"prod1"}'
  run "$APIGEE" env export "$T/snap" --no-bundles --no-kvms --show-credentials
  assert_status "export" 0
  : >"$FAKE_CURL_LOG"
  route GET "$ORGP/developers/d1%40example.com/apps/app1\$" 200 '{"name":"app1","credentials":[{"consumerKey":"GENERATED"}]}'
  run "$APIGEE" --yes env import "$T/snap"
  assert_status "import" 0
  assert_contains "secret restored" "$(sed -n '/^body: /,$p' "$FAKE_CURL_LOG" | tr -d ' \n')" "SECRET456"
}

test_product_export_handles_names_with_spaces() {
  use_x
  route GET "$ORGP/apiproducts\$" 200 '["Bank Account","prod1"]'
  route GET "$ORGP/apiproducts/Bank%20Account\$" 200 '{"name":"Bank Account"}'
  route GET "$ORGP/apiproducts/prod1\$" 200 '{"name":"prod1"}'
  run "$APIGEE" product export "$T/ex"
  assert_status "export" 0
  assert_eq "spaced name" "Bank Account" "$(jq -r .name "$T/ex/products/Bank Account.json")"
}

test_env_import_continues_after_a_failing_step() {
  use_x
  make_export "$APP_JSON"
  route GET "$ORGP/environments/test/keyvaluemaps\$" 403 '{"error":{"code":403}}'
  run "$APIGEE" --yes env import "$T/in" --no-bundles
  assert_status "reports failure" 1
  assert_contains "kvm step failed" "$ERR" "key value map import step failed; continuing"
  assert_contains "developers still imported" "$(posts)" "POST /organizations/org1/developers"
  assert_contains "apps still imported" "$(posts)" "POST /organizations/org1/developers/d1%40example.com/apps"
}

test_env_import_dry_run_counts_bundles_as_would_import() {
  use_x
  make_export "$APP_JSON"
  mkdir -p "$T/in/proxies"
  printf 'zipdata' >"$T/in/proxies/p1-rev3.zip"
  run "$APIGEE" -n env import "$T/in" --deploy
  assert_status "dry run succeeds" 0
  assert_contains "bundle counted" "$ERR" "bundles: 1 created, 0 updated, 0 already existed (skipped), 0 failed"
  assert_not_contains "no failure message" "$ERR" "import of proxy p1"
}

test_env_import_stops_once_on_wrong_gcloud_identity() {
  use_x
  make_export "$APP_JSON"
  export CLOUDSDK_CORE_ACCOUNT=me@example.com
  route POST 'oauth2.googleapis.com/tokeninfo$' 200 '{"email":"someone.else@gmail.com"}'
  run "$APIGEE" --yes env import "$T/in"
  assert_status "aborted" 1
  assert_eq "mismatch reported exactly once" "1" "$(printf '%s\n' "$ERR" | grep -c "gcloud gave a token for")"
  assert_eq "nothing sent to Apigee" "" "$(posts | grep -v tokeninfo)"
  assert_not_contains "no per-step noise" "$ERR" "step failed; continuing"
}

run_tests
