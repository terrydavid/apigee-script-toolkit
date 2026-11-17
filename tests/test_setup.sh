#!/usr/bin/env bash
# setup/doctor.sh and setup/install.sh.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

DOCTOR="$ROOT/setup/doctor.sh"
INSTALL="$ROOT/setup/install.sh"

test_doctor_passes_on_x() {
  use_x
  route GET '/organizations/org1$' 200 '{"name":"org1"}'
  route GET '/environments/test$' 200 '{"name":"test"}'
  run "$DOCTOR"
  assert_status "doctor" 0
  assert_contains "ok" "$OUT" "GET organization 'org1' succeeded"
  assert_contains "env" "$OUT" "environment 'test' exists"
  assert_contains "done" "$OUT" "All checks passed."
}

test_doctor_edge_credentials() {
  use_edge
  route GET '/organizations/org1$' 200 '{"name":"org1"}'
  run "$DOCTOR"
  assert_status "doctor" 0
  assert_contains "creds" "$OUT" "Edge credentials found (not shown)"
  assert_not_contains "secret never printed" "$OUT$ERR" "s3cr3t-pass"
}

test_doctor_edge_missing_password_gives_fix() {
  use_edge
  : >"$FAKE_KEYCHAIN_FILE"
  run "$DOCTOR"
  assert_status "doctor" 1
  assert_contains "fail" "$OUT" "no Edge password found"
  assert_contains "fix" "$OUT" "security add-generic-password"
}

test_doctor_requires_platform_and_org() {
  run "$DOCTOR"
  assert_status "unconfigured" 1
  assert_contains "platform" "$OUT" "APIGEE_PLATFORM is not set"
  assert_contains "org" "$OUT" "APIGEE_ORG is not set"
}

test_doctor_rejects_unknown_platform() {
  export APIGEE_PLATFORM=bogus APIGEE_ORG=org1
  run "$DOCTOR"
  assert_status "bad platform" 1
  assert_contains "msg" "$OUT" "not supported"
}

test_doctor_reports_http_errors() {
  use_x
  route GET '/organizations/org1$' 403 '{"error":"denied"}'
  run "$DOCTOR"
  assert_status "403" 1
  assert_contains "403" "$OUT" "HTTP 403"
  : >"$FAKE_CURL_ROUTES"
  route GET '/organizations/org1$' 404 '{}'
  run "$DOCTOR"
  assert_status "404" 1
  assert_contains "404" "$OUT" "not found"
}

test_doctor_flags_missing_env() {
  use_x
  route GET '/organizations/org1$' 200 '{"name":"org1"}'
  route GET '/environments/test$' 404 '{}'
  run "$DOCTOR"
  assert_status "env missing" 1
  assert_contains "msg" "$OUT" "environment 'test' not readable"
}

test_doctor_cli_overrides_and_help() {
  route GET '/organizations/other$' 200 '{"name":"other"}'
  run "$DOCTOR" --platform x --org other
  assert_status "overrides" 0
  assert_contains "org" "$OUT" "APIGEE_ORG=other"
  run "$DOCTOR" --help
  assert_status "help" 0
  run "$DOCTOR" --bogus
  assert_status "bad option" 2
}

test_install_check_and_options() {
  run "$INSTALL" --check
  assert_status "check" 0
  assert_contains "bash" "$OUT" "bash"
  assert_contains "mode" "$OUT" "check mode"
  run "$INSTALL" --help
  assert_status "help" 0
  run "$INSTALL" --bogus
  assert_status "bad option" 2
}

test_install_check_fails_without_json_engine() {
  # PATH with only the basics: no jq, no python3.
  local bin="$T/bin" tool
  mkdir -p "$bin"
  for tool in bash env dirname cat sed grep awk head tr uname mktemp rm printf curl; do
    command -v "$tool" >/dev/null 2>&1 && ln -s "$(command -v "$tool")" "$bin/$tool" 2>/dev/null
  done
  PATH="$bin" run "$BASH" "$INSTALL" --check
  assert_status "missing jq and python3" 1
  assert_contains "msg" "$ERR" "one of jq or python3 is required"
}

run_tests
