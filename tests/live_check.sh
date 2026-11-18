#!/usr/bin/env bash
#
# Live, READ-ONLY smoke check of one proxy against a real Apigee X org.
# Not part of tests/run.sh (needs network + gcloud login); run it by hand:
#
#   gcloud auth login            # once
#   bash tests/live_check.sh [PROXY] [ORG] [ENV]
#
# Defaults: hello-apigee-api  corp-apigee  dev
# Only GET requests are made. Output is also saved to tests/live_check_<env>.log
set -u
unset CDPATH # a CDPATH makes `cd` print the directory and corrupts $(cd ... && pwd)
PROXY="${1:-hello-apigee-api}"
ORG="${2:-corp-apigee}"
ENVN="${3:-dev}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LOG="$ROOT/tests/live_check_${ENVN}.log"
APIGEE="$ROOT/bin/apigee"
export APIGEE_PLATFORM=x APIGEE_ORG="$ORG" APIGEE_ENV="$ENVN"

pass=0
fail=0
: >"$LOG"

# check NAME CMD... ; optional EXPECT (substring) via $EXPECT
check() {
  local name="$1"
  shift
  local out rc
  out="$("$@" 2>&1)"
  rc=$?
  {
    printf '=== %s\n$ %s\n%s\n' "$name" "$*" "$out"
  } >>"$LOG"
  if [[ $rc -eq 0 && ( -z "${EXPECT:-}" || "$out" == *"$EXPECT"* ) ]]; then
    printf 'PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s (exit %s%s)\n' "$name" "$rc" "${EXPECT:+, expected '$EXPECT'}"
    fail=$((fail + 1))
  fi
}

printf 'Live check: proxy=%s org=%s env=%s\n' "$PROXY" "$ORG" "$ENVN"
EXPECT="" check "auth token obtainable"      bash -c "'$APIGEE' token >/dev/null"
EXPECT="$ORG"   check "org get"              "$APIGEE" org get
EXPECT="$ENVN"  check "env list has env"     "$APIGEE" env list
EXPECT="$ENVN"  check "env get"              "$APIGEE" env get
EXPECT="$PROXY" check "proxy list has proxy" "$APIGEE" proxy list
EXPECT=""       check "proxy revisions"      "$APIGEE" proxy revisions "$PROXY"
EXPECT=""       check "proxy deployed"       "$APIGEE" proxy deployed "$PROXY"
EXPECT=""       check "proxy latest"         "$APIGEE" proxy latest "$PROXY"
EXPECT=""       check "env health"           "$APIGEE" env health

printf '\n%s passed, %s failed. Details: %s\n' "$pass" "$fail" "$LOG"
[[ $fail -eq 0 ]]
