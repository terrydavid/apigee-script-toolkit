#!/usr/bin/env bash
# Every resource and verb has help that works without any configuration.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

test_global_help() {
  run "$APIGEE" --help
  assert_status "--help" 0
  assert_contains "usage" "$OUT" "Usage: apigee"
  run "$APIGEE"
  assert_status "no args" 0
  run "$APIGEE" --version
  assert_contains "version" "$OUT" "apigee toolkit"
}

test_every_resource_and_verb_help() {
  local res verb module
  for res in proxy sharedflow kvm target-server keystore truststore app developer product cache env virtualhost envgroup user org token profile; do
    run "$APIGEE" "$res" --help
    assert_status "$res --help" 0
    assert_contains "$res usage" "$OUT" "Usage: apigee"
    case "$res" in
      target-server) module=targetserver ;;
      *) module="$res" ;;
    esac
    for verb in $(bash -c ". '$ROOT/lib/platform.sh'; for m in '$ROOT'/libexec/*.sh; do . \"\$m\"; done; ${module}_verbs"); do
      [[ "$res" == token ]] && continue
      run "$APIGEE" "$res" "$verb" --help
      assert_status "$res $verb --help" 0
      assert_contains "$res $verb usage" "$OUT" "Usage: apigee $res"
    done
  done
}

test_unknown_resource_and_verb() {
  run "$APIGEE" nope list
  assert_status "unknown resource" 1
  run "$APIGEE" kvm frobnicate
  assert_status "unknown verb" 1
  assert_contains "msg" "$ERR" "unknown kvm verb"
}

test_doctor_and_install_help() {
  run "$ROOT/setup/doctor.sh" --help
  assert_status "doctor help" 0
  run "$ROOT/setup/install.sh" --help
  assert_status "install help" 0
}

test_help_wording() {
  run "$APIGEE" proxy --help
  assert_contains "plural" "$OUT" "List API proxies in the organization"
  assert_contains "article" "$OUT" "List revisions of an API proxy"
  assert_not_contains "typo" "$OUT" "proxys"
  run "$APIGEE" proxy list --help
  assert_contains "list plural" "$OUT" "List all API proxies"
  run "$APIGEE" sharedflow --help
  assert_contains "sf plural" "$OUT" "List shared flows in the organization"
  run "$APIGEE" doctor --help
  assert_status "doctor help" 0
  assert_eq "no leading blank line" "Verify apigee-toolkit configuration and authentication for the selected" \
    "$(printf '%s\n' "$OUT" | head -n 1)"
}

test_doctor_runs_read_only_org_get() {
  use_x
  route GET '/v1/organizations/org1$' 200 '{"name":"org1"}'
  run "$APIGEE" doctor
  assert_status "doctor" 0
  assert_contains "org ok" "$OUT" "GET organization 'org1' succeeded"
  assert_eq "only GETs" "" "$(grep '^===' "$FAKE_CURL_LOG" | grep -v '=== GET')"
}

test_doctor_reports_missing_platform() {
  run "$ROOT/setup/doctor.sh"
  assert_status "doctor fails" 1
  assert_contains "fix" "$OUT" "APIGEE_PLATFORM is not set"
}

run_tests
