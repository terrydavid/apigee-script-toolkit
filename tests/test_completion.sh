#!/usr/bin/env bash
# Tests for completions/apigee.bash and setup/install-completion.sh.
. "$(dirname "$0")/lib.sh"

COMP="$ROOT/completions/apigee.bash"

# complete "apigee env im" -> prints the candidates, one per line
complete_words() {
  bash -c '
    . "$1"; shift
    COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 ))
    COMP_LINE="$*"; COMP_POINT=${#COMP_LINE}
    _apigee
    printf "%s\n" "${COMPREPLY[@]}"
  ' _ "$COMP" "$@"
}

test_completes_resources_and_aliases() {
  OUT="$(complete_words apigee ta)"
  assert_contains "target-server" "$OUT" "target-server"
  OUT="$(complete_words apigee sh)"
  assert_contains "sharedflow" "$OUT" "sharedflow"
  OUT="$(complete_words apigee ins)"
  assert_contains "instance" "$OUT" "instance"
}

test_completes_verbs_per_resource() {
  OUT="$(complete_words apigee env im)"
  assert_eq "env im" "import" "$OUT"
  OUT="$(complete_words apigee sf clean)"
  assert_eq "alias resolves" "clean-revisions" "$OUT"
  OUT="$(complete_words apigee instance att)"
  assert_contains "attach" "$OUT" "attachments"
}

test_completes_global_options_before_resource() {
  OUT="$(complete_words apigee --pl)"
  assert_eq "platform" "--platform" "$OUT"
  OUT="$(complete_words apigee --platform '')"
  assert_contains "x" "$OUT" "hybrid"
}

test_completes_verb_options() {
  OUT="$(complete_words apigee --org o env import dir --exist)"
  assert_eq "existing" "--existing-revisions" "$OUT"
  OUT="$(complete_words apigee env import dir --service-account-)"
  assert_contains "from" "$OUT" "--service-account-from"
}

test_completes_profile_names() {
  mkdir -p "$T/cfg/profiles"
  : > "$T/cfg/profiles/alpha.env"
  : > "$T/cfg/profiles/beta.env"
  OUT="$(APIGEE_CONFIG_HOME="$T/cfg" complete_words apigee profile use al)"
  assert_eq "profile" "alpha" "$OUT"
}

test_verb_table_matches_modules() {
  local res verbs expected
  for res in proxy sharedflow kvm targetserver keystore truststore app developer product \
    cache env virtualhost envgroup instance server stats report user org token profile; do
    expected="$(cd "$ROOT" && bash -c '
      export APIGEE_TOOLKIT_HOME="$PWD"; . lib/platform.sh 2>/dev/null
      for f in libexec/*.sh; do . "$f" 2>/dev/null; done
      "$1_verbs"' _ "$res" | tr '\n' ' ')"
    verbs="$(complete_words apigee "$res" '' | tr '\n' ' ')"
    assert_eq "verbs of $res" "$expected" "$verbs"
  done
}

test_installer_is_idempotent_and_reversible() {
  local rc="$T/rc"
  printf 'export X=1\n' >"$rc"
  run "$ROOT/setup/install-completion.sh" --rc "$rc"
  assert_status "install" 0
  run "$ROOT/setup/install-completion.sh" --rc "$rc"
  assert_status "again" 0
  assert_eq "one block" 1 "$(grep -c '>>> apigee-toolkit completion' "$rc" | head -1)"
  assert_contains "source line" "$(cat "$rc")" "completions/apigee.bash"
  run "$ROOT/setup/install-completion.sh" --rc "$rc" --uninstall
  assert_status "uninstall" 0
  assert_eq "restored" "export X=1" "$(cat "$rc")"
}

test_installer_zsh_adds_bashcompinit() {
  local rc="$T/zrc"
  run "$ROOT/setup/install-completion.sh" --rc "$rc" --zsh
  assert_status "zsh" 0
  assert_contains "bashcompinit" "$(cat "$rc")" "bashcompinit"
}

run_tests
