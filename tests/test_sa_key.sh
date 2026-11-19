#!/usr/bin/env bash
# Tests for service-account key authentication (no login needed).
. "$(dirname "$0")/lib.sh"

SAKEY="$ROOT/setup/gcloud-sa-key.sh"

assert_absent() { if [[ -e "$2" ]]; then assert_eq "$1" "absent" "exists"; else assert_eq "$1" "absent" "absent"; fi; }

use_key_gcloud() {
  mkdir -p "$T/gbin"
  export GLOG="$T/gcloud.log" CFG="$T/cfg"
  : >"$GLOG"
  cat >"$T/gbin/gcloud" <<'FAKE'
#!/usr/bin/env bash
a="$*"
printf '%s\n' "$a" >>"$GLOG"
case "$a" in
  "iam service-accounts keys create "*)
    if [[ -n "${FAKE_KEY_DENIED:-}" ]]; then
      echo "ERROR: Key creation is not allowed on this service account. constraints/iam.disableServiceAccountKeyCreation" >&2; exit 1
    fi
    f="${a#iam service-accounts keys create }"; f="${f%% *}"
    printf '{"type":"service_account","client_email":"apigee-toolkit@proj1.iam.gserviceaccount.com"}' >"$f" ;;
  "auth print-access-token") printf 'print-token account=%s\n' "${CLOUDSDK_CORE_ACCOUNT:-}" >>"$GLOG"
    if [[ -n "${CLOUDSDK_CORE_ACCOUNT:-}" ]]; then echo "ERROR: account mismatch" >&2; exit 1; fi
    echo "tok-key:${CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE:-none}" ;;
  "config get-value project") echo "proj1" ;;
  "config get-value auth/impersonate_service_account") ;;
  "iam service-accounts keys list "*) echo "KEYID1" ;;
  "iam service-accounts keys delete "*) ;;
  *) ;;
esac
FAKE
  chmod +x "$T/gbin/gcloud"
  export PATH="$T/gbin:$PATH"
}

test_toolkit_uses_key_from_env_and_skips_identity_check() {
  use_x
  printf '{}' >"$T/k.json"
  export APIGEE_SA_KEY="$T/k.json" CLOUDSDK_CORE_ACCOUNT=someone@else.com
  run "$APIGEE" token print
  assert_status "ok" 0
  assert_contains "key used" "$(cat "$FAKE_CURL_LOG")" "override=$T/k.json"
  assert_not_contains "no identity probe" "$(cat "$FAKE_CURL_LOG")" "tokeninfo"
}

test_toolkit_uses_default_key_file() {
  use_x
  mkdir -p "$XDG_CONFIG_HOME/apigee-toolkit"
  printf '{}' >"$XDG_CONFIG_HOME/apigee-toolkit/sa-key.json"
  run "$APIGEE" token print
  assert_status "ok" 0
  assert_contains "default key" "$(cat "$FAKE_CURL_LOG")" "override=$XDG_CONFIG_HOME/apigee-toolkit/sa-key.json"
}

test_toolkit_without_key_does_not_set_override() {
  use_x
  run "$APIGEE" token print
  assert_status "ok" 0
  assert_contains "plain" "$(cat "$FAKE_CURL_LOG")" "account= override="
}

test_script_creates_private_key_and_verifies() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg"
  run "$SAKEY" --yes
  assert_status "ok" 0
  assert_eq "file mode" 600 "$(stat -c %a "$T/cfg/sa-key.json")"
  assert_contains "create" "$(cat "$GLOG")" "iam service-accounts keys create $T/cfg/sa-key.json.new --iam-account=apigee-toolkit@proj1.iam.gserviceaccount.com"
  assert_contains "verified" "$OUT" "token ok"
  assert_not_contains "key text never printed" "$OUT$ERR" "private_key"
}

test_script_ignores_cloudsdk_core_account_when_verifying() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg" CLOUDSDK_CORE_ACCOUNT=person@example.com
  run "$SAKEY" --yes
  assert_status "ok" 0
  assert_contains "verified" "$OUT" "token ok"
}

test_script_shows_gcloud_error_when_token_fails() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg" GCLOUD_KEY_WAIT=0 GCLOUD_KEY_TRIES=2
  sed -i 's|echo "tok-key:|echo "ERROR: invalid_grant: key rejected" >\&2; exit 1; echo "tok-key:|' "$T/gbin/gcloud"
  run "$SAKEY" --yes
  assert_status "fails" 1
  assert_contains "reason shown" "$ERR$OUT" "invalid_grant: key rejected"
}

test_script_dry_run_changes_nothing() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg"
  run "$SAKEY" -n
  assert_status "dry" 0
  assert_absent "no file" "$T/cfg/sa-key.json"
  assert_not_contains "no create" "$(cat "$GLOG")" "keys create"
}

test_script_explains_org_policy_block() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg" FAKE_KEY_DENIED=1
  run "$SAKEY" --yes
  assert_status "fails" 1
  assert_contains "policy named" "$ERR$OUT" "disableServiceAccountKeyCreation"
  assert_absent "no file" "$T/cfg/sa-key.json"
}

test_script_refuses_to_overwrite_without_force() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg"
  mkdir -p "$T/cfg"; printf '{}' >"$T/cfg/sa-key.json"
  run "$SAKEY" --yes
  assert_status "refuses" 1
  assert_contains "says why" "$ERR$OUT" "already exists"
}

test_script_remove_deletes_local_key() {
  use_key_gcloud
  export APIGEE_CONFIG_HOME="$T/cfg"
  mkdir -p "$T/cfg"; printf '{}' >"$T/cfg/sa-key.json"
  run "$SAKEY" --remove --yes
  assert_status "ok" 0
  assert_absent "gone" "$T/cfg/sa-key.json"
}

run_tests
