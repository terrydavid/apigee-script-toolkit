#!/usr/bin/env bash
# URL building and auth header selection for both platforms.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

test_x_url_and_gcloud_bearer() {
  use_x
  route GET '/v1/organizations/org1/apis$' 200 '{"proxies":[{"name":"b"},{"name":"a"}]}'
  run "$APIGEE" proxy list
  assert_status "proxy list" 0
  assert_eq "sorted names" "a
b" "$OUT"
  assert_contains "url" "$(curl_log)" "=== GET https://apigee.googleapis.com/v1/organizations/org1/apis"
  assert_contains "bearer via config file" "$(curl_log)" 'config: header = "Authorization: Bearer fake-x-token"'
  assert_not_contains "token not in argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "fake-x-token"
}

test_x_account_is_passed_to_gcloud() {
  use_x
  export CLOUDSDK_CORE_ACCOUNT=ops@example.com
  run "$APIGEE" env list
  assert_status "env list" 0
  assert_contains "gcloud account" "$(curl_log)" "gcloud auth print-access-token account=ops@example.com"
}

test_x_token_fetched_once_per_invocation() {
  use_x
  route GET '/apis/p1/revisions$' 200 '["1","2"]'
  route GET '/apis/p1/deployments$' 200 '{}'
  run "$APIGEE" --yes proxy clean-revisions p1 --keep 5
  assert_status "clean-revisions" 0
  assert_eq "one gcloud call" "1" "$(grep -c 'gcloud auth print-access-token' "$FAKE_CURL_LOG")"
}

test_edge_default_url_and_basic_auth_from_keychain() {
  use_edge
  route GET '/v1/organizations/org1/apis$' 200 '["p2","p1"]'
  run "$APIGEE" proxy list
  assert_status "proxy list" 0
  assert_eq "names" "p1
p2" "$OUT"
  assert_contains "edge url" "$(curl_log)" "=== GET https://api.enterprise.apigee.com/v1/organizations/org1/apis"
  assert_contains "basic auth via config" "$(curl_log)" 'config: user = "user@example.com:s3cr3t-pass"'
  assert_not_contains "password not in argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "s3cr3t-pass"
}

test_edge_custom_mgmt_url_with_and_without_v1() {
  use_edge
  export APIGEE_EDGE_MGMT_URL=https://mgmt.example.com:8443/
  run "$APIGEE" env list
  assert_contains "custom url" "$(curl_log)" "=== GET https://mgmt.example.com:8443/v1/organizations/org1/environments"
  : >"$FAKE_CURL_LOG"
  export APIGEE_EDGE_MGMT_URL=https://mgmt.example.com:8443/v1
  run "$APIGEE" env list
  assert_contains "no double v1" "$(curl_log)" "=== GET https://mgmt.example.com:8443/v1/organizations/org1/environments"
}

test_edge_password_from_env_var() {
  use_edge
  : >"$FAKE_KEYCHAIN_FILE"
  export APIGEE_EDGE_PASSWORD='env pa"ss'
  run "$APIGEE" env list
  assert_status "env list" 0
  assert_contains "escaped in config" "$(curl_log)" 'config: user = "user@example.com:env pa\"ss"'
}

test_edge_missing_password_explains_fix() {
  use_edge
  : >"$FAKE_KEYCHAIN_FILE"
  run "$APIGEE" env list
  assert_status "no password" 1
  assert_contains "fix hint" "$ERR" "security add-generic-password"
}

test_edge_oauth_token_flow_and_cache() {
  use_edge
  export APIGEE_EDGE_AUTH=oauth
  printf 'apigee-toolkit-edge-sso-client client cid:csecret\n' >>"$FAKE_KEYCHAIN_FILE"
  route POST 'login.apigee.com/oauth/token' 200 '{"access_token":"edge-oauth-token","expires_in":1799}'
  run "$APIGEE" env list
  assert_status "env list" 0
  local log
  log="$(curl_log)"
  assert_contains "token endpoint" "$log" "=== POST https://login.apigee.com/oauth/token"
  assert_contains "client creds in config" "$log" 'config: user = "cid:csecret"'
  assert_contains "password grant in config" "$log" 'config: data-urlencode = "password=s3cr3t-pass"'
  assert_contains "bearer used" "$log" 'config: header = "Authorization: Bearer edge-oauth-token"'
  assert_not_contains "secrets not in argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "csecret"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" env list
  assert_not_contains "cached token reused" "$(curl_log)" "oauth/token"
}

test_apigee_token_override() {
  use_x
  export APIGEE_TOKEN=preset-token
  run "$APIGEE" env list
  assert_contains "preset bearer" "$(curl_log)" 'Authorization: Bearer preset-token'
  assert_not_contains "no gcloud" "$(curl_log)" "gcloud auth"
}

test_token_command() {
  use_x
  run "$APIGEE" token
  assert_eq "token" "fake-x-token" "$OUT"
  run "$APIGEE" token --header
  assert_eq "header" "Authorization: Bearer fake-x-token" "$OUT"
}

test_platform_required_and_validated() {
  export APIGEE_ORG=org1
  run "$APIGEE" proxy list
  assert_status "no platform" 1
  assert_contains "message" "$ERR" "APIGEE_PLATFORM is not set"
  run "$APIGEE" --platform foo proxy list
  assert_status "bad platform" 1
  assert_contains "message" "$ERR" "unsupported APIGEE_PLATFORM"
}

test_platform_specific_resources() {
  use_x
  run "$APIGEE" virtualhost list
  assert_status "vhost on x" 1
  assert_contains "vhost msg" "$ERR" "not supported on Apigee X/hybrid"
  run "$APIGEE" cache clear c1 --yes
  assert_contains "cache msg" "$ERR" "not supported on Apigee X/hybrid"
  run "$APIGEE" user list
  assert_contains "user msg" "$ERR" "not supported on Apigee X/hybrid"
  use_edge
  run "$APIGEE" envgroup list
  assert_status "envgroup on edge" 1
  assert_contains "envgroup msg" "$ERR" "not supported on Apigee Edge"
  assert_eq "no requests sent" "" "$(grep '^===' "$FAKE_CURL_LOG")"
}

test_hybrid_uses_x_api() {
  export APIGEE_PLATFORM=hybrid APIGEE_ORG=org1 APIGEE_ENV=test
  route GET '/environments/test/targetservers$' 200 '["ts1"]'
  run "$APIGEE" target-server list
  assert_eq "ts" "ts1" "$OUT"
  assert_contains "x url" "$(curl_log)" "https://apigee.googleapis.com/v1/organizations/org1/environments/test/targetservers"
}

test_url_encoding_of_names() {
  use_x
  run "$APIGEE" developer get 'a+b@example.com'
  assert_contains "encoded" "$(curl_log)" "/developers/a%2Bb%40example.com"
}

test_profile_use_and_precedence() {
  mkdir -p "$XDG_CONFIG_HOME/apigee-toolkit/profiles"
  printf 'APIGEE_PLATFORM=edge\nAPIGEE_ORG=prof-org\nAPIGEE_ENV=prod\nAPIGEE_EDGE_AUTH=basic\nAPIGEE_EDGE_USER=user@example.com\n' \
    >"$XDG_CONFIG_HOME/apigee-toolkit/profiles/work.env"
  printf 'apigee-toolkit-edge user@example.com pw\n' >>"$FAKE_KEYCHAIN_FILE"
  run "$APIGEE" profile use work
  assert_status "profile use" 0
  run "$APIGEE" profile current
  assert_eq "current" "work" "$OUT"
  run "$APIGEE" env list
  assert_contains "profile org" "$(curl_log)" "api.enterprise.apigee.com/v1/organizations/prof-org/environments"
  : >"$FAKE_CURL_LOG"
  export APIGEE_ORG=env-org
  run "$APIGEE" env list
  assert_contains "env var beats default profile" "$(curl_log)" "/organizations/env-org/environments"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --profile work env list
  assert_contains "explicit profile beats env" "$(curl_log)" "/organizations/prof-org/environments"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --profile work --org cli-org env list
  assert_contains "cli flag beats profile" "$(curl_log)" "/organizations/cli-org/environments"
}

test_apigee_env_must_be_sourced() {
  run bash "$ROOT/bin/apigee-env" example-x
  assert_status "executed" 1
  assert_contains "message" "$ERR" "must be sourced"
  local out
  out="$(bash -c ". '$ROOT/bin/apigee-env' example-x 2>/dev/null; printf '%s %s %s' \"\$APIGEE_PLATFORM\" \"\$APIGEE_ORG\" \"\$APIGEE_PROFILE\"")"
  assert_eq "sourced" "x my-gcp-project example-x" "$out"
}

test_apigee_env_works_in_bash_and_zsh() {
  local sh out shells="bash"
  command -v zsh >/dev/null 2>&1 && shells="bash zsh"
  for sh in $shells; do
    # shellcheck disable=SC2016  # expanded by the inner shell
    out="$(cd "$ROOT" && "$sh" -c 'source bin/apigee-env example-x 2>/dev/null && printf "%s %s" "$APIGEE_PROFILE" "$APIGEE_ORG"')"
    assert_eq "$sh relative path" "example-x my-gcp-project" "$out"
    out="$(cd "$T" && "$sh" -c "source '$ROOT/bin/apigee-env' example-x 2>/dev/null && printf '%s:' \"\$APIGEE_PROFILE\" && command -v apigee")"
    assert_eq "$sh from another dir (and bin on PATH)" "example-x:$ROOT/bin/apigee" "$out"
    out="$(cd "$T" && "$sh" -c "source '$ROOT/bin/apigee-env' example-x 2>/dev/null; source '$ROOT/bin/apigee-env' --unset; printf '[%s]' \"\${APIGEE_ORG-}\"")"
    assert_eq "$sh --unset" "[]" "$out"
    run "$sh" -c "source '$ROOT/bin/apigee-env' no-such-profile"
    assert_status "$sh missing profile" 1
    assert_contains "$sh missing profile message" "$ERR" "profile no-such-profile not found"
  done
  if [[ "$shells" == *zsh* ]]; then
    run zsh "$ROOT/bin/apigee-env" example-x
    assert_status "zsh executed" 1
    assert_contains "zsh must be sourced" "$ERR" "must be sourced"
  fi
}

test_profile_show_redacts_secret_like_names() {
  mkdir -p "$XDG_CONFIG_HOME/apigee-toolkit/profiles"
  cat >"$XDG_CONFIG_HOME/apigee-toolkit/profiles/leaky.env" <<'EOF'
# comment
APIGEE_PLATFORM=edge
APIGEE_ORG=org1
APIGEE_EDGE_SSO_CLIENT=cid:client-secret-1
APIGEE_EDGE_MFA_CODE=123456
export APIGEE_EDGE_PASSWORD='pw-value-2'
APIGEE_EDGE_PASSCODE=passcode-3
APIGEE_TOKEN=token-4
my_api_key=key-5
Custom_Secret_Thing=secret-6
EOF
  run "$APIGEE" profile show leaky
  assert_status "show" 0
  assert_contains "plain setting" "$OUT" "APIGEE_ORG=org1"
  assert_contains "platform" "$OUT" "APIGEE_PLATFORM=edge"
  local v
  for v in APIGEE_EDGE_SSO_CLIENT APIGEE_EDGE_MFA_CODE APIGEE_EDGE_PASSWORD APIGEE_EDGE_PASSCODE APIGEE_TOKEN my_api_key Custom_Secret_Thing; do
    assert_contains "$v redacted" "$OUT" "$v=<redacted>"
  done
  for v in client-secret-1 123456 pw-value-2 passcode-3 token-4 key-5 secret-6; do
    assert_not_contains "value hidden" "$OUT" "$v"
  done
}

run_tests
