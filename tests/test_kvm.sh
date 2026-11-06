#!/usr/bin/env bash
# KVM export/import round trips on both platforms and both file formats.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

PEM='-----BEGIN CERTIFICATE-----
MIIBszCCAVmgAwIBAgIUfakeFAKEfake
-----END CERTIFICATE-----'

x_routes_for_map1() {
  route GET '/environments/test/keyvaluemaps$' 200 '["map1"]'
  route GET '/keyvaluemaps/map1/entries\?pageSize=100$' 200 \
    "{\"keyValueEntries\":[{\"name\":\"host\",\"value\":\"svc.example.com\"},{\"name\":\"cert\",\"value\":$(printf '%s' "$PEM" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],\"nextPageToken\":\"cert\"}"
  route GET '/keyvaluemaps/map1/entries\?pageSize=100&pageToken=cert$' 200 \
    '{"keyValueEntries":[{"name":"semi","value":"a;b"}]}'
}

test_x_export_json_follows_pages() {
  use_x
  x_routes_for_map1
  run "$APIGEE" kvm export --out "$T/exp"
  assert_status "export" 0
  local doc="$T/exp/map1.json"
  [[ -f "$doc" ]] || fail "no export file"
  assert_eq "name" "map1" "$(jq -r .name "$doc")"
  assert_eq "encrypted" "true" "$(jq -r .encrypted "$doc")"
  assert_eq "entry count" "3" "$(jq '.entries | length' "$doc")"
  assert_eq "pem preserved" "$PEM" "$(jq -r '.entries[] | select(.name == "cert") | .value' "$doc")"
  assert_eq "file mode" "600" "$(stat -f '%Lp' "$doc" 2>/dev/null || stat -c '%a' "$doc")"
}

test_edge_export_reads_map_and_flags_masked_values() {
  use_edge
  route GET '/environments/test/keyvaluemaps/m2$' 200 '{"name":"m2","encrypted":true,"entry":[{"name":"k","value":"*****"}]}'
  run "$APIGEE" kvm export m2 --out "$T/exp"
  assert_status "export" 0
  assert_contains "warns" "$ERR" "Edge masks its values"
  assert_eq "encrypted flag" "true" "$(jq -r .encrypted "$T/exp/m2.json")"
}

test_edge_export_via_reader_proxy() {
  use_edge
  route GET '/environments/test/keyvaluemaps/m2$' 200 '{"name":"m2","encrypted":true,"entry":[{"name":"k","value":"*****"}]}'
  route GET 'reader.example.com/kvm\?mapname=m2&key=k$' 200 'real-value'
  run "$APIGEE" kvm export m2 --out "$T/exp" --reader-url https://reader.example.com/kvm
  assert_status "export" 0
  assert_eq "real value" "real-value" "$(jq -r '.entries[0].value' "$T/exp/m2.json")"
  assert_not_contains "reader gets no mgmt creds" "$(awk '/reader.example.com/{f=1} f && /^config:/{print}' "$FAKE_CURL_LOG")" "s3cr3t-pass"
}

test_x_import_creates_map_and_updates_existing_entries() {
  use_x
  cat >"$T/map9.json" <<EOF
{"name":"map9","encrypted":true,"entries":[{"name":"a","value":"1"},{"name":"b","value":"2"}]}
EOF
  route GET '/environments/test/keyvaluemaps$' 200 '[]'
  route POST '/keyvaluemaps/map9/entries$' 409 '{"error":{"code":409}}'
  run "$APIGEE" --yes kvm import "$T/map9.json"
  assert_status "import" 0
  local log
  log="$(curl_log)"
  assert_contains "create map" "$log" "=== POST https://apigee.googleapis.com/v1/organizations/org1/environments/test/keyvaluemaps"
  assert_contains "create body" "$log" '"name": "map9"'
  assert_contains "update a via PUT" "$log" "=== PUT https://apigee.googleapis.com/v1/organizations/org1/environments/test/keyvaluemaps/map9/entries/a"
  assert_contains "update b via PUT" "$log" "/keyvaluemaps/map9/entries/b"
  assert_contains "entry body" "$log" 'body: {"name":"a","value":"1"}'
}

test_edge_import_updates_with_post_to_entry() {
  use_edge
  printf '{"name":"m","encrypted":false,"entries":[{"name":"a","value":"1"}]}' >"$T/m.json"
  route GET '/environments/test/keyvaluemaps$' 200 '["m"]'
  route POST '/keyvaluemaps/m/entries$' 409 '{"code":"keyvaluemap.service.entry.already.exists"}'
  run "$APIGEE" --yes kvm import "$T/m.json"
  assert_status "import" 0
  assert_contains "edge update" "$(curl_log)" "=== POST https://api.enterprise.apigee.com/v1/organizations/org1/environments/test/keyvaluemaps/m/entries/a"
  assert_not_contains "no create" "$(curl_log)" '"encrypted": false'
}

test_round_trip_lines_format() {
  use_x
  x_routes_for_map1
  run "$APIGEE" kvm export map1 --format lines --out "$T/exp"
  assert_status "export lines" 0
  local f="$T/exp/map1.kvm"
  assert_eq "first line" "host;svc.example.com" "$(head -n 1 "$f")"
  assert_contains "pem block kept multi-line" "$(cat "$f")" "cert;-----BEGIN CERTIFICATE-----
MIIBszCCAVmgAwIBAgIUfakeFAKEfake
-----END CERTIFICATE-----"
  assert_contains "semicolon in value" "$(cat "$f")" "semi;a;b"

  : >"$FAKE_CURL_LOG"
  : >"$FAKE_CURL_ROUTES"
  route GET '/environments/test/keyvaluemaps$' 200 '["map1"]'
  run "$APIGEE" --yes kvm import "$f"
  assert_status "import lines" 0
  local bodies
  bodies="$(grep '^body:' "$FAKE_CURL_LOG" | sed 's/^body: //')"
  assert_eq "same entries after round trip" \
    "$(jq -c '.keyValueEntries[]' "$T/resp/2" "$T/resp/3")" \
    "$(printf '%s\n' "$bodies" | jq -c '{name, value}')"
}

test_round_trip_json_format() {
  use_x
  x_routes_for_map1
  run "$APIGEE" kvm export map1 --out "$T/exp"
  : >"$FAKE_CURL_LOG"
  : >"$FAKE_CURL_ROUTES"
  route GET '/environments/test/keyvaluemaps$' 200 '["map1"]'
  run "$APIGEE" --yes kvm import "$T/exp"
  assert_status "import dir" 0
  assert_eq "entries" \
    "$(jq -c '.keyValueEntries[]' "$T/resp/2" "$T/resp/3")" \
    "$(grep '^body:' "$FAKE_CURL_LOG" | sed 's/^body: //' | jq -c '{name, value}')"
}

test_legacy_lines_file_with_indented_pem_and_crlf() {
  use_x
  printf 'user; svc-user\r\n\r\ncert;-----BEGIN CERTIFICATE-----\r\nAAAA\r\n-----END CERTIFICATE-----\r\nnosemicolon\r\n' >"$T/legacy.kvm"
  route GET '/environments/test/keyvaluemaps$' 200 '["legacy"]'
  run "$APIGEE" --yes kvm import "$T/legacy.kvm"
  assert_status "import" 0
  assert_contains "warns on bad line" "$ERR" "skipping line without ';'"
  local bodies
  bodies="$(grep '^body:' "$FAKE_CURL_LOG" | sed 's/^body: //')"
  assert_contains "value kept verbatim" "$bodies" '{"name":"user","value":" svc-user"}'
  assert_contains "pem joined" "$bodies" '{"name":"cert","value":"-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----"}'
}

test_put_value_from_file_keeps_secret_out_of_argv() {
  use_x
  printf 'top-secret-value' >"$T/v"
  run "$APIGEE" --yes kvm put map1 apikey --value-file "$T/v"
  assert_status "put" 0
  assert_contains "body" "$(curl_log)" 'body: {"name":"apikey","value":"top-secret-value"}'
  assert_not_contains "argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "top-secret-value"
}

test_get_single_value_and_scopes() {
  use_x
  route GET '/organizations/org1/keyvaluemaps/om/entries/k$' 200 '{"name":"k","value":"v1"}'
  run "$APIGEE" kvm get om k --scope org
  assert_eq "value" "v1" "$OUT"
  route GET '/organizations/org1/apis/p1/keyvaluemaps$' 200 '["pm"]'
  run "$APIGEE" kvm list --scope proxy:p1
  assert_eq "proxy scope" "pm" "$OUT"
}

test_import_refuses_masked_values_unless_allowed() {
  use_edge
  mkdir -p "$T/in"
  printf '{"name":"good","encrypted":true,"entries":[{"name":"a","value":"real"}]}' >"$T/in/good.json"
  printf '{"name":"m2","encrypted":true,"entries":[{"name":"ok","value":"a*b"},{"name":"k","value":"*****"},{"name":"one","value":"*"}]}' >"$T/in/m2.json"
  printf 'plain;value\nstars;***\n' >"$T/legacy.kvm"
  route GET '/environments/test/keyvaluemaps$' 200 '["good","m2","legacy"]'

  run "$APIGEE" --yes kvm import "$T/in"
  assert_status "refused" 1
  assert_contains "message" "$ERR" "refusing to import masked values"
  assert_contains "names the keys" "$ERR" "m2.json: k one"
  assert_not_contains "real value with * is fine" "$ERR" " ok "
  assert_eq "nothing written, not even the clean file" "" "$(grep -E '^=== (POST|PUT)' "$FAKE_CURL_LOG")"

  run "$APIGEE" --dry-run kvm import "$T/legacy.kvm"
  assert_status "lines format refused" 1
  assert_contains "lines key" "$ERR" "legacy.kvm: stars"

  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes kvm import "$T/in" --allow-masked
  assert_status "allowed" 0
  assert_contains "warns" "$ERR" "--allow-masked"
  assert_contains "masked value sent" "$(curl_log)" 'body: {"name":"k","value":"*****"}'
}

test_get_value_preserves_trailing_newlines() {
  use_x
  local pem_json
  pem_json="$(printf '%s\n\n' "$PEM" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  route GET '/organizations/org1/keyvaluemaps/om/entries/cert$' 200 "{\"name\":\"cert\",\"value\":$pem_json}"
  route GET '/organizations/org1/keyvaluemaps/om/entries/plain$' 200 '{"name":"plain","value":"v1"}'
  printf '%s\n\n' "$PEM" >"$T/expected"
  run "$APIGEE" kvm get om cert --scope org
  assert_status "get" 0
  cmp -s "$T/out" "$T/expected" || fail "management value not byte-identical" "$(od -c "$T/out" | tail -n 3)"
  run "$APIGEE" kvm get om plain --scope org
  printf 'v1' >"$T/expected"
  cmp -s "$T/out" "$T/expected" || fail "no newline added to piped output" "$(od -c "$T/out")"
  run "$APIGEE" kvm get om cert --scope org --json
  assert_eq "json keeps newlines" "true" "$(jq --arg v "$PEM" '.value == ($v + "\n\n")' "$T/out")"
}

test_reader_proxy_values_keep_trailing_newline() {
  use_edge
  route GET '/environments/test/keyvaluemaps/m2$' 200 '{"name":"m2","encrypted":true,"entry":[{"name":"k","value":"*****"}]}'
  route GET 'reader.example.com/kvm\?mapname=m2&key=k$' 200 "$PEM

"
  printf '%s\n\n' "$PEM" >"$T/expected"
  run "$APIGEE" kvm get m2 k --reader-url https://reader.example.com/kvm
  assert_status "get" 0
  cmp -s "$T/out" "$T/expected" || fail "reader value not byte-identical" "$(od -c "$T/out" | tail -n 3)"
  run "$APIGEE" kvm export m2 --out "$T/exp" --reader-url https://reader.example.com/kvm
  assert_status "export" 0
  assert_eq "export keeps newlines" "true" "$(jq --arg v "$PEM" '.entries[0].value == ($v + "\n\n")' "$T/exp/m2.json")"
}

test_x_rejects_unencrypted_map() {
  use_x
  run "$APIGEE" --yes kvm create m --no-encrypt
  assert_status "rejected" 1
  assert_contains "msg" "$ERR" "always encrypted"
}

run_tests
