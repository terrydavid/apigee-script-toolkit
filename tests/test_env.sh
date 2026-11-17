#!/usr/bin/env bash
# org / env / cache / virtualhost / envgroup / user resources.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

ENVP='/organizations/org1/environments/test'

test_org_get() {
  use_x
  route GET '/organizations/org1$' 200 '{"name":"org1","projectId":"p"}'
  run "$APIGEE" org get
  assert_status "org get" 0
  assert_eq "name" "org1" "$(printf '%s' "$OUT" | jq -r .name)"
}

test_env_list_sorted() {
  use_x
  route GET '/organizations/org1/environments$' 200 '["prod","dev"]'
  run "$APIGEE" env list
  assert_status "list" 0
  assert_eq "sorted" "dev
prod" "$OUT"
}

test_env_get_accepts_env_argument() {
  use_x
  route GET '/environments/prod$' 200 '{"name":"prod"}'
  run "$APIGEE" env get prod
  assert_status "get" 0
  assert_contains "url" "$(curl_log)" "/environments/prod"
}

test_env_health_ok_x() {
  use_x
  route GET "$ENVP\$" 200 '{"name":"test"}'
  route GET "$ENVP/deployments\$" 200 '{"deployments":[{"apiProxy":"p1","revision":"3","state":"READY"}]}'
  run "$APIGEE" env health
  assert_status "healthy" 0
  assert_contains "line" "$OUT" "p1"
  assert_contains "count" "$OUT" "1 deployment(s)"
}

test_env_health_fails_on_error_state() {
  use_x
  route GET "$ENVP\$" 200 '{"name":"test"}'
  route GET "$ENVP/deployments\$" 200 '{"deployments":[{"apiProxy":"p1","revision":"3","state":"ERROR"}]}'
  run "$APIGEE" env health
  assert_status "unhealthy" 1
  assert_contains "warn" "$ERR" "unhealthy deployments"
}

test_env_health_edge_format() {
  use_edge
  route GET "$ENVP\$" 200 '{"name":"test"}'
  route GET "$ENVP/deployments\$" 200 '{"aPIProxy":[{"name":"p1","revision":[{"name":"2","state":"deployed"}]}]}'
  run "$APIGEE" env health
  assert_status "edge healthy" 0
  assert_contains "p1" "$OUT" "p1"
}

test_env_health_unreachable_env() {
  use_x
  route GET "$ENVP\$" 404 '{"error":"nope"}'
  run "$APIGEE" env health
  assert_status "missing env" 1
  assert_contains "msg" "$ERR" "not reachable"
}

test_env_export_writes_target_servers_with_private_dir() {
  use_x
  route GET "$ENVP/targetservers\$" 200 '["ts1"]'
  route GET "$ENVP/targetservers/ts1\$" 200 '{"name":"ts1","host":"h"}'
  run "$APIGEE" env export "$T/snap" --no-bundles --no-kvms
  assert_status "export" 0
  assert_eq "ts json" "h" "$(jq -r .host "$T/snap/targetservers/ts1.json")"
  assert_eq "dir mode" "700" "$(stat -c '%a' "$T/snap" 2>/dev/null || stat -f '%Lp' "$T/snap")"
}

test_env_export_requires_dir() {
  use_x
  run "$APIGEE" env export
  assert_status "no dir" 1
  assert_contains "msg" "$ERR" "missing DIR"
}

test_env_export_edge_includes_virtualhosts() {
  use_edge
  route GET "$ENVP/targetservers\$" 200 '[]'
  route GET "$ENVP/virtualhosts\$" 200 '["default"]'
  route GET "$ENVP/virtualhosts/default\$" 200 '{"name":"default","port":"443"}'
  run "$APIGEE" env export "$T/snap" --no-bundles --no-kvms
  assert_status "export" 0
  assert_eq "vhost" "443" "$(jq -r .port "$T/snap/virtualhosts/default.json")"
}

test_cache_is_edge_only() {
  use_x
  run "$APIGEE" cache list
  assert_status "x refused" 1
  assert_contains "msg" "$ERR" "Edge"
}

test_cache_list_and_clear_edge() {
  use_edge
  route GET "$ENVP/caches\$" 200 '["c2","c1"]'
  run "$APIGEE" cache list
  assert_eq "sorted" "c1
c2" "$OUT"
  run "$APIGEE" --yes cache clear c1 --prefix 'a b'
  assert_status "clear" 0
  assert_contains "POST" "$(curl_log)" "=== POST"
  assert_contains "encoded query" "$(curl_log)" "caches/c1/entries?action=clear&prefix=a%20b"
}

test_cache_clear_requires_confirmation() {
  use_edge
  run "$APIGEE" cache clear c1
  assert_status "no tty, no --yes" 1
  assert_eq "no POST" "" "$(grep '^=== POST' "$FAKE_CURL_LOG")"
}

test_virtualhost_edge_only() {
  use_x
  run "$APIGEE" virtualhost list
  assert_status "x refused" 1
  use_edge
  route GET "$ENVP/virtualhosts\$" 200 '["default","secure"]'
  run "$APIGEE" virtualhost list
  assert_status "edge" 0
  assert_eq "names" "default
secure" "$OUT"
}

test_envgroup_x_only_and_get_fetches_attachments() {
  use_edge
  run "$APIGEE" envgroup list
  assert_status "edge refused" 1
  use_x
  route GET '/envgroups$' 200 '{"environmentGroups":[{"name":"g1"}]}'
  run "$APIGEE" envgroup list
  assert_eq "list" "g1" "$OUT"
  run "$APIGEE" envgroup get g1
  assert_status "get" 0
  assert_contains "attachments" "$(curl_log)" "/envgroups/g1/attachments"
}

test_user_list_edge_only() {
  use_x
  run "$APIGEE" user list
  assert_status "x refused" 1
  use_edge
  route GET '/organizations/org1/users$' 200 '["b@example.com","a@example.com"]'
  run "$APIGEE" user list
  assert_eq "sorted" "a@example.com
b@example.com" "$OUT"
}

run_tests
