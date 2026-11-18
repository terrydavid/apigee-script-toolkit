#!/usr/bin/env bash
# A user-set CDPATH makes `cd` print the directory it enters (and can resolve a
# relative path somewhere else). Every entry point must still find its own home.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# Relative invocations from $ROOT with CDPATH=$ROOT make `cd bin/..` resolve
# through CDPATH and print the path.
with_cdpath() { (cd "$ROOT" && CDPATH="$ROOT" "$@"); }

test_apigee_finds_its_home_with_cdpath() {
  run with_cdpath bin/apigee --version
  assert_status "bin/apigee" 0
  assert_contains "version" "$OUT" "apigee toolkit"
  run with_cdpath bin/apigee target-server --help
  assert_status "sourcing lib files" 0
  assert_contains "help" "$OUT" "Usage: apigee target-server"
}

test_apigee_resolves_symlink_with_cdpath() {
  ln -s "$ROOT/bin/apigee" "$T/apigee-link"
  run bash -c "cd '$T' && CDPATH='$T:$ROOT' ./apigee-link --version"
  assert_status "symlink" 0
  assert_contains "version" "$OUT" "apigee toolkit"
}

test_setup_scripts_work_with_cdpath() {
  run with_cdpath setup/doctor.sh --help
  assert_status "doctor" 0
  run with_cdpath setup/install.sh --help
  assert_status "install" 0
}

test_apigee_env_works_with_cdpath() {
  run bash -c "cd '$ROOT' && CDPATH='$ROOT' && . bin/apigee-env --unset >/dev/null 2>&1; printf '%s' \"\$PATH\""
  assert_status "source" 0
  assert_not_contains "no stray newline in PATH" "$(printf '%s' "$OUT" | tr '\n' '#')" "#"
}

test_test_runner_itself_works_with_cdpath() {
  run bash -c "cd '$ROOT' && CDPATH='$ROOT' tests/run.sh test_help.sh"
  assert_status "run.sh" 0
  assert_contains "result" "$OUT" "ALL TESTS PASSED"
}

run_tests
