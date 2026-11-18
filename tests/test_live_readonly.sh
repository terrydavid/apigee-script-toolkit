#!/usr/bin/env bash
# tests/live_readonly.py against the fake curl/gcloud: it must only GET, keep no
# command output, mask developer emails, and show the legacy command per row.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

LIVE="$ROOT/tests/live_readonly.py"
EP='/organizations/org1'

sweep_routes() {
  route GET "$EP\$" 200 '{"name":"org1"}'
  route GET "$EP/environments\$" 200 '["test"]'
  route GET "$EP/environments/test\$" 200 '{"name":"test"}'
  route GET "$EP/environments/test/deployments\$" 200 '{"deployments":[{"apiProxy":"p1","revision":"2","state":"READY"}]}'
  route GET "$EP/apis\$" 200 '{"proxies":[{"name":"p1"},{"name":"p2"}]}'
  route GET "$EP/sharedflows\$" 200 '{"sharedFlows":[{"name":"s1"}]}'
  route GET '/revisions$' 200 '["1","2"]'
  route GET '/deployments$' 200 '{"deployments":[{"environment":"test","revision":"2"}]}'
  route GET "$EP/developers\$" 200 '{"developer":[{"email":"secret.dev@example.com"}]}'
  route GET "$EP/apiproducts\$" 200 '{"apiProduct":[{"name":"prod1"}]}'
  route GET "$EP/apps\$" 200 '{"app":[{"appId":"app-id-123"}]}'
  route GET '/keystores$' 200 '["ks1"]'
  route GET '/keyvaluemaps$' 200 '["m1"]'
  route GET '/targetservers$' 200 '["t1"]'
  route GET "$EP/envgroups\$" 200 '{"environmentGroups":[{"name":"g1"}]}'
}

sweep() { run python3 -I "$LIVE" run --org org1 --env test --platform x --sample 1 --out "$T/live" "$@"; }

test_sweep_only_sends_get_requests() {
  use_x
  sweep_routes
  sweep
  assert_status "sweep" 0
  local methods
  methods="$(grep '^=== ' "$FAKE_CURL_LOG" | awk '{print $2}' | sort -u)"
  assert_eq "only GET" "GET" "$methods"
  assert_contains "ran commands" "$OUT" "passed, 0 failed"
}

test_sweep_covers_each_read_resource() {
  use_x
  sweep_routes
  sweep
  local cmds
  cmds="$(jq -r '.rows[].command' "$T/live/results.json")"
  local want
  for want in "apigee org get" "apigee env list" "apigee env health" "apigee proxy list" \
    "apigee proxy revisions p1" "apigee proxy deployed p1 --all-envs" "apigee sharedflow latest s1" \
    "apigee kvm list --scope org" "apigee target-server get t1" "apigee keystore get ks1" \
    "apigee truststore get ks1" "apigee product get prod1" "apigee envgroup get g1"; do
    assert_contains "ran: $want" "$cmds" "$want"
  done
}

test_report_shows_legacy_command_for_each_row() {
  use_x
  sweep_routes
  sweep
  assert_contains "env health legacy" "$OUT" '`apigee env health` | `checkHealth`'
  assert_contains "proxy list legacy" "$OUT" '`apigee proxy list` | `getApis`'
  assert_contains "column header" "$OUT" "Legacy command"
  assert_contains "skipped writers" "$OUT" "writes files"
}

test_no_command_output_is_saved_and_developer_is_masked() {
  use_x
  sweep_routes
  sweep
  assert_eq "only two files" "report.md
results.json" "$(ls "$T/live" | sort)"
  assert_not_contains "email not in results" "$(cat "$T/live/results.json")" "secret.dev@example.com"
  assert_not_contains "email not in report" "$OUT" "secret.dev@example.com"
  assert_not_contains "app id not in report" "$OUT" "app-id-123"
  assert_contains "mask used" "$OUT" "<developer-1>"
  assert_eq "private file" "600" "$(stat -c '%a' "$T/live/results.json" 2>/dev/null || stat -f '%Lp' "$T/live/results.json")"
}

test_no_redact_shows_names() {
  use_x
  sweep_routes
  sweep --no-redact
  assert_contains "email shown" "$OUT" "secret.dev@example.com"
}

test_failures_are_classified_and_exit_status_is_nonzero() {
  use_x
  route GET "$EP\$" 403 '{"error":{"code":403,"message":"denied"}}'
  sweep
  assert_status "failing sweep" 1
  assert_contains "permission group" "$OUT" "**permission**"
  assert_contains "root cause" "$OUT" "apigee org get"
}

test_edge_runs_edge_only_commands_and_skips_envgroup() {
  use_edge
  route GET '/caches$' 200 '["c1"]'
  route GET '/virtualhosts$' 200 '["default"]'
  route GET "$EP/users\$" 200 '["u@example.com"]'
  run python3 -I "$LIVE" run --org org1 --env test --platform edge --sample 1 --out "$T/live"
  local cmds
  cmds="$(jq -r '.rows[] | select(.status != "SKIP") | .command' "$T/live/results.json")"
  assert_contains "cache" "$cmds" "apigee cache list"
  assert_contains "virtualhost" "$cmds" "apigee virtualhost get default"
  assert_not_contains "no envgroup" "$cmds" "envgroup"
}

test_gcloud_crosscheck_detects_mismatch() {
  use_x
  sweep_routes
  export FAKE_GCLOUD_LIST=$'p1\np2\np3\n'
  sweep --gcloud
  assert_contains "mismatch flagged" "$OUT" "MISMATCH"
  unset FAKE_GCLOUD_LIST
}

test_report_subcommand_rerenders() {
  use_x
  sweep_routes
  sweep
  run python3 -I "$LIVE" report --out "$T/live"
  assert_contains "rerendered" "$OUT" "# Live read-only sweep: org1 / test (x)"
}

test_write_files_switch_runs_the_writing_commands() {
  use_x
  sweep_routes
  route GET '/keyvaluemaps/m1/entries$' 200 '{"keyValueEntries":[{"name":"k","value":"topsecret"}]}'
  sweep --write-files "$T/dump"
  assert_status "sweep" 0
  assert_not_contains "no longer skipped" "$OUT" "pass --write-files DIR to run"
  assert_contains "reported" "$OUT" "Files written"
  assert_contains "private" "$OUT" "all files are private"
  assert_contains "env export legacy" "$OUT" '`apigee env export'
  assert_eq "kvm file written" "m1.json" "$(ls "$T/dump/kvms-env")"
  assert_eq "bundle written" "p1.zip" "$(ls "$T/dump/proxies")"
  assert_eq "dump dir mode" "700" "$(stat -c '%a' "$T/dump" 2>/dev/null || stat -f '%Lp' "$T/dump")"
  assert_not_contains "contents not in report" "$OUT" "topsecret"
  assert_not_contains "contents not in results" "$(cat "$T/live/results.json")" "topsecret"
}

test_write_files_show_credentials_reaches_env_export() {
  use_x
  sweep_routes
  sweep --write-files "$T/dump" --show-credentials
  assert_contains "flag passed" "$(jq -r '.rows[].command' "$T/live/results.json")" "env export $T/dump/env-export --show-credentials"
  assert_contains "secrets warning" "$OUT" "app keys and secrets"
}

test_default_sweep_writes_no_files() {
  use_x
  sweep_routes
  sweep
  assert_eq "no dump" "no" "$([[ -e $T/dump ]] && echo yes || echo no)"
}

run_tests
