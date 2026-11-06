# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are consumed by the test files
#
# Minimal test helpers (no bats). Each tests/test_*.sh sources this file,
# defines test_* functions and calls run_tests.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$TESTS_DIR/.." && pwd)"
APIGEE="$ROOT/bin/apigee"
ORIG_PATH="$PATH"
ORIG_TMPDIR="${TMPDIR:-/tmp}"
PASSED=0
FAILED=0
CURRENT=""

setup() {
  T="$(mktemp -d "$ORIG_TMPDIR/apigee-test.XXXXXX")"
  export HOME="$T/home"
  mkdir -p "$HOME" "$T/tmp" "$T/resp"
  export XDG_CONFIG_HOME="$T/config" XDG_CACHE_HOME="$T/cache" TMPDIR="$T/tmp"
  local v
  for v in APIGEE_PLATFORM APIGEE_ORG APIGEE_ENV APIGEE_X_API_URL APIGEE_EDGE_MGMT_URL \
    APIGEE_EDGE_AUTH APIGEE_EDGE_USER APIGEE_EDGE_TOKEN_URL APIGEE_EDGE_KEYCHAIN_SERVICE \
    APIGEE_EDGE_SSO_KEYCHAIN_SERVICE APIGEE_KVM_READER_URL APIGEE_KVM_READER_AUTH \
    APIGEE_NO_TOKEN_CACHE CLOUDSDK_CORE_ACCOUNT APIGEE_TOKEN APIGEE_PROFILE APIGEE_CONFIG_HOME \
    APIGEE_CACHE_HOME APIGEE_EDGE_PASSWORD APIGEE_EDGE_SSO_CLIENT APIGEE_EDGE_PASSCODE \
    APIGEE_EDGE_MFA_CODE APIGEE_DRY_RUN APIGEE_YES APIGEE_DEBUG APIGEE_TMPDIR; do
    unset "$v"
  done
  export PATH="$TESTS_DIR/fakebin:$ORIG_PATH"
  export FAKE_CURL_LOG="$T/curl.log" FAKE_CURL_ROUTES="$T/routes" FAKE_KEYCHAIN_FILE="$T/keychain"
  : >"$FAKE_CURL_LOG"
  : >"$FAKE_CURL_ROUTES"
  : >"$FAKE_KEYCHAIN_FILE"
  ROUTE_N=0
}

teardown() {
  rm -rf "$T"
}

use_x() {
  export APIGEE_PLATFORM=x APIGEE_ORG=org1 APIGEE_ENV=test
}

use_edge() {
  export APIGEE_PLATFORM=edge APIGEE_ORG=org1 APIGEE_ENV=test APIGEE_EDGE_AUTH=basic APIGEE_EDGE_USER=user@example.com
  printf 'apigee-toolkit-edge user@example.com s3cr3t-pass\n' >>"$FAKE_KEYCHAIN_FILE"
}

# route METHOD URL_REGEX CODE BODY
route() {
  ROUTE_N=$((ROUTE_N + 1))
  printf '%s' "$4" >"$T/resp/$ROUTE_N"
  printf '%s %s %s %s\n' "$1" "$2" "$3" "$T/resp/$ROUTE_N" >>"$FAKE_CURL_ROUTES"
}

# run CMD... — captures OUT, ERR, STATUS; stdin is never a terminal.
run() {
  "$@" >"$T/out" 2>"$T/err" </dev/null
  STATUS=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}

curl_log() { cat "$FAKE_CURL_LOG"; }

fail() {
  FAILED=$((FAILED + 1))
  printf '  FAIL %s: %s\n' "$CURRENT" "$1"
  [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/      | /'
  return 0
}

assert_eq() {
  if [[ "$2" != "$3" ]]; then
    fail "$1" "expected: $2
actual:   $3"
    return 1
  fi
}

assert_contains() {
  if [[ "$2" != *"$3"* ]]; then
    fail "$1: missing '$3'" "$2"
    return 1
  fi
}

assert_not_contains() {
  if [[ "$2" == *"$3"* ]]; then
    fail "$1: unexpected '$3'" "$2"
    return 1
  fi
}

assert_status() {
  if [[ "$STATUS" != "$2" ]]; then
    fail "$1: exit status $STATUS, expected $2" "$ERR"
    return 1
  fi
}

run_tests() {
  local fn before
  for fn in $(declare -F | awk '{print $3}' | grep '^test_'); do
    CURRENT="$fn"
    before="$FAILED"
    setup
    "$fn"
    teardown
    if [[ "$FAILED" == "$before" ]]; then
      PASSED=$((PASSED + 1))
      printf '  ok   %s\n' "$fn"
    fi
  done
  printf '%s: %d passed, %d failed\n' "$(basename "$0")" "$PASSED" "$FAILED"
  [[ "$FAILED" == 0 ]]
}
