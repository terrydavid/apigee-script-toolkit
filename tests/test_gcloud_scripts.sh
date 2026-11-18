#!/usr/bin/env bash
# Tests for setup/gcloud-login.sh and setup/gcloud-impersonate.sh (fake gcloud, fake curl).
. "$(dirname "$0")/lib.sh"

LOGIN="$ROOT/setup/gcloud-login.sh"
IMPERSONATE="$ROOT/setup/gcloud-impersonate.sh"

# A recording gcloud that sits in front of the shared fake.
use_script_gcloud() {
  mkdir -p "$T/gbin" "$T/gcfg"
  export CLOUDSDK_CONFIG="$T/gcfg" GLOG="$T/gcloud.log" GIMP="$T/impersonate"
  : >"$GLOG"
  cat >"$T/gbin/gcloud" <<'FAKE'
#!/usr/bin/env bash
a="$*"
printf '%s\n' "$a" >>"$GLOG"
case "$a" in
  "auth login"*) echo "Go to the following link in your browser: https://accounts.google.com/o/oauth2/auth?x=1" ;;
  "auth print-access-token --impersonate-service-account="*)
    if [[ -n "${FAKE_TOKEN_DENIED:-}" ]]; then echo "ERROR: PERMISSION_DENIED: getAccessToken" >&2; exit 1; fi
    echo "tok-${a##*=}" ;;
  "auth print-access-token --account="*) echo "tok-${a##*=}" ;;
  "auth print-access-token") echo "tok-${CLOUDSDK_CORE_ACCOUNT:-nobody}" ;;
  "config get-value account") echo "me@example.com" ;;
  "config get-value project") echo "proj1" ;;
  "config get-value auth/impersonate_service_account") cat "$GIMP" 2>/dev/null ;;
  "config set auth/impersonate_service_account "*) printf '%s\n' "${a##* }" >"$GIMP" ;;
  "config unset auth/impersonate_service_account") rm -f "$GIMP" ;;
  "iam service-accounts describe"*) exit 1 ;;
esac
exit 0
FAKE
  chmod +x "$T/gbin/gcloud"
  export PATH="$T/gbin:$PATH"
  : >"$T/gcfg/access_tokens.db"
}

tokeninfo_for() { route GET "access_token=$1\$" 200 "{\"email\":\"$2\",\"expires_in\":\"3500\"}"; }

test_login_resets_prints_url_and_checks() {
  use_script_gcloud
  tokeninfo_for tok-me@example.com me@example.com
  run "$LOGIN" me@example.com
  assert_status "all checks pass" 0
  assert_contains "revoked" "$(cat "$GLOG")" "auth revoke me@example.com"
  assert_contains "browser-less login" "$(cat "$GLOG")" "auth login me@example.com --no-launch-browser"
  assert_contains "URL shown" "$OUT" "https://accounts.google.com/o/oauth2/auth"
  assert_contains "private window hint" "$OUT" "PRIVATE/INCOGNITO"
  assert_eq "token cache removed" "no" "$([[ -e $T/gcfg/access_tokens.db ]] && echo yes || echo no)"
  assert_contains "named-account check" "$OUT" "--account=me@example.com gives a token for me@example.com"
  assert_contains "default check" "$OUT" "default token is for me@example.com"
  assert_contains "done" "$OUT" "All checks passed"
}

test_login_fails_when_token_is_for_another_account() {
  use_script_gcloud
  tokeninfo_for tok-me@example.com other@gmail.com
  run "$LOGIN" me@example.com
  assert_status "check fails" 1
  assert_contains "says which" "$OUT" "gives a token for 'other@gmail.com'"
  assert_contains "advice" "$OUT" "fresh"
}

test_login_check_only_changes_nothing() {
  use_script_gcloud
  tokeninfo_for tok-me@example.com me@example.com
  run "$LOGIN" --check me@example.com
  assert_status "ok" 0
  assert_not_contains "no revoke" "$(cat "$GLOG")" "auth revoke"
  assert_not_contains "no login" "$(cat "$GLOG")" "auth login"
  assert_eq "cache untouched" "yes" "$([[ -e $T/gcfg/access_tokens.db ]] && echo yes || echo no)"
}

test_login_needs_an_account() {
  use_script_gcloud
  run "$LOGIN"
  assert_status "usage" 2
}

test_impersonate_dry_run_changes_nothing() {
  use_script_gcloud
  run "$IMPERSONATE" -n --project proj1 --user me@example.com
  assert_status "dry run" 0
  assert_contains "shows create" "$OUT" "gcloud iam service-accounts create apigee-toolkit"
  assert_contains "shows role" "$OUT" "roles/apigee.admin"
  assert_contains "shows token creator" "$OUT" "roles/iam.serviceAccountTokenCreator"
  assert_not_contains "nothing ran" "$(cat "$GLOG")" "services enable"
  assert_eq "config untouched" "no" "$([[ -e $GIMP ]] && echo yes || echo no)"
}

test_impersonate_sets_everything_and_verifies() {
  use_script_gcloud
  tokeninfo_for tok-apigee-toolkit@proj1.iam.gserviceaccount.com apigee-toolkit@proj1.iam.gserviceaccount.com
  run "$IMPERSONATE" -y --project proj1 --user me@example.com --read-only
  assert_status "setup" 0
  local g; g="$(cat "$GLOG")"
  assert_contains "api" "$g" "services enable iamcredentials.googleapis.com"
  assert_contains "created" "$g" "iam service-accounts create apigee-toolkit"
  assert_contains "read-only role" "$g" "--role roles/apigee.readOnlyAdmin"
  assert_not_contains "no admin role" "$g" "roles/apigee.admin"
  assert_contains "token creator on the SA only" "$g" "service-accounts add-iam-policy-binding apigee-toolkit@proj1.iam.gserviceaccount.com"
  assert_contains "user" "$g" "--member user:me@example.com"
  assert_eq "config set" "apigee-toolkit@proj1.iam.gserviceaccount.com" "$(cat "$GIMP")"
  assert_contains "verified" "$OUT" "token belongs to apigee-toolkit@proj1.iam.gserviceaccount.com"
}

test_impersonate_no_config_leaves_gcloud_alone() {
  use_script_gcloud
  tokeninfo_for tok-apigee-toolkit@proj1.iam.gserviceaccount.com apigee-toolkit@proj1.iam.gserviceaccount.com
  run "$IMPERSONATE" -y --no-config --project proj1 --user me@example.com
  assert_status "ok" 0
  assert_eq "config untouched" "no" "$([[ -e $GIMP ]] && echo yes || echo no)"
  assert_contains "tells how" "$OUT" "gcloud config set auth/impersonate_service_account"
}

test_impersonate_fails_when_token_is_not_the_service_account() {
  use_script_gcloud
  tokeninfo_for tok-apigee-toolkit@proj1.iam.gserviceaccount.com me@example.com
  run "$IMPERSONATE" -y --project proj1 --user me@example.com
  assert_status "verify fails" 1
  assert_contains "reason" "$OUT" "expected apigee-toolkit@proj1.iam.gserviceaccount.com"
  assert_eq "gcloud not switched to impersonation" "no" "$([[ -e $GIMP ]] && echo yes || echo no)"
}

test_impersonate_denied_token_leaves_gcloud_unchanged() {
  use_script_gcloud
  export FAKE_TOKEN_DENIED=1 GCLOUD_IMPERSONATE_WAIT=0
  run "$IMPERSONATE" -y --project proj1 --user me@example.com
  assert_status "denied" 1
  assert_contains "says not switched" "$ERR" "gcloud was NOT switched to impersonation"
  assert_contains "shows the error" "$ERR" "PERMISSION_DENIED"
  assert_contains "retried" "$OUT" "try 12 of 12"
  assert_eq "config unchanged" "no" "$([[ -e $GIMP ]] && echo yes || echo no)"
  assert_contains "setup steps kept" "$(cat "$GLOG")" "add-iam-policy-binding apigee-toolkit"
}

test_impersonate_undo() {
  use_script_gcloud
  echo sa@x >"$GIMP"
  run "$IMPERSONATE" --undo
  assert_status "undone" 0
  assert_eq "config cleared" "no" "$([[ -e $GIMP ]] && echo yes || echo no)"
}

test_impersonate_needs_a_user() {
  use_script_gcloud
  run "$IMPERSONATE" -n --project proj1
  assert_status "usage" 2
}

run_tests
