#!/usr/bin/env bash
# Tests for 'apigee server' (OPDK only).
. "$(dirname "$0")/lib.sh"

use_opdk() {
  export APIGEE_PLATFORM=opdk APIGEE_ORG=org1 APIGEE_ENV=test APIGEE_EDGE_MGMT_URL=http://opdk.example.com:8080 APIGEE_EDGE_USER=admin@example.com
  printf 'apigee-toolkit-edge admin@example.com opdk-pass\n' >>"$FAKE_KEYCHAIN_FILE"
}

test_server_commands_refuse_other_platforms() {
  use_x
  run "$APIGEE" server list
  assert_status "x" 1
  use_edge
  run "$APIGEE" server list
  assert_status "edge" 1
  assert_contains "why" "$ERR" "only on Apigee Edge for Private Cloud (OPDK)"
}

test_server_list_get_and_env_servers() {
  use_opdk
  route GET '/v1/servers$' 200 '["u1","u2"]'
  route GET '/v1/servers/u1$' 200 '{"uUID":"u1","internalIP":"10.0.0.1","externalIP":"1.2.3.4"}'
  route GET '/v1/organizations/org1/environments/test/servers$' 200 '["u2"]'
  route GET '/v1/organizations/org1/servers$' 200 '["u1","u2"]'
  run "$APIGEE" server list
  assert_eq "list" "u1
u2" "$OUT"
  run "$APIGEE" server get u1
  assert_contains "ip" "$OUT" '"internalIP": "10.0.0.1"'
  run "$APIGEE" server env-servers
  assert_eq "env servers" "u2" "$OUT"
  run "$APIGEE" server org-servers
  assert_eq "org servers" "u1
u2" "$OUT"
}

test_server_ips_resolves_each_org_server() {
  use_opdk
  route GET '/v1/organizations/org1/servers$' 200 '["u1","u2"]'
  route GET '/v1/servers/u1$' 200 '{"externalIP":"1.1.1.1","internalIP":"10.0.0.1"}'
  route GET '/v1/servers/u2$' 200 '{"externalIP":"2.2.2.2","internalIP":"10.0.0.2"}'
  run "$APIGEE" server ips
  assert_eq "external" "u1 1.1.1.1
u2 2.2.2.2" "$OUT"
  run "$APIGEE" server ips --internal
  assert_eq "internal" "u1 10.0.0.1
u2 10.0.0.2" "$OUT"
}

test_server_attach_and_detach_post_form_after_confirmation() {
  use_opdk
  route POST '/environments/test/servers$' 200 '{}'
  run "$APIGEE" server attach u1
  assert_status "needs confirmation" 1
  run "$APIGEE" --yes server attach u1
  assert_status "attach" 0
  assert_contains "add" "$(cat "$FAKE_CURL_LOG")" "body: action=add&uuid=u1"
  run "$APIGEE" --yes server detach u1
  assert_status "detach" 0
  assert_contains "remove" "$(cat "$FAKE_CURL_LOG")" "body: action=remove&uuid=u1"
  run "$APIGEE" -n server attach u2
  assert_status "dry" 0
  assert_not_contains "not sent" "$(cat "$FAKE_CURL_LOG")" "uuid=u2"
}

test_server_health_checks_each_port_without_credentials() {
  use_opdk
  route GET ':8080/v1/servers/self/up$' 200 'true'
  route GET ':8081/v1/servers/self/up$' 200 'true'
  route GET ':8082/v1/servers/self/up$' 503 'false'
  run "$APIGEE" server health node1.example.com
  assert_status "one port down" 1
  assert_contains "mgmt" "$OUT" "8080 ok"
  assert_contains "router" "$OUT" "8081 ok"
  assert_contains "mp down" "$OUT" "8082 DOWN"
  assert_not_contains "no creds sent" "$(cat "$FAKE_CURL_LOG")" "opdk-pass"
}

run_tests
