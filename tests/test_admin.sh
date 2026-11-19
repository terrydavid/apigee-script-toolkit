#!/usr/bin/env bash
# RBAC (user/role), environment and organization lifecycle, proxy delete, resourcefile.
. "$(dirname "$0")/lib.sh"

use_opdk() {
  export APIGEE_PLATFORM=opdk APIGEE_ORG=org1 APIGEE_ENV=test APIGEE_EDGE_MGMT_URL=http://opdk.example.com:8080 APIGEE_EDGE_USER=admin@example.com
  printf 'apigee-toolkit-edge admin@example.com opdk-pass\n' >>"$FAKE_KEYCHAIN_FILE"
}

test_user_create_takes_password_from_env() {
  use_edge
  run "$APIGEE" --yes user create a@b.com --first Ann --last Lee
  assert_status "no password" 1
  APIGEE_NEW_USER_PASSWORD='Pw-1234' run "$APIGEE" --yes user create a@b.com --first Ann --last Lee
  assert_status "create" 0
  assert_contains "POST" "$(curl_log)" "=== POST"
  assert_contains "email" "$(curl_log)" '"emailId":"a@b.com"'
  assert_contains "password in body" "$(curl_log)" '"password":"Pw-1234"'
  assert_not_contains "not on argv" "$(grep '^argv:' "$FAKE_CURL_LOG")" "Pw-1234"
  APIGEE_NEW_USER_PASSWORD=x run "$APIGEE" --yes user create a@b.com --password hunter2
  assert_status "flag refused" 1
}

test_user_delete_and_roles() {
  use_edge
  route GET '/users/a%40b.com/userroles$' 200 '{"role":[{"name":"r1"},{"name":"r2"}]}'
  run "$APIGEE" user roles a@b.com
  assert_status "roles" 0
  assert_eq "names" "r1
r2" "$OUT"
  run "$APIGEE" --yes user delete a@b.com
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
  assert_contains "url" "$(curl_log)" "/users/a%40b.com"
}

test_role_lifecycle() {
  use_edge
  route GET '/organizations/org1/userroles$' 200 '["admin","viewer"]'
  run "$APIGEE" role list
  assert_eq "list" "admin
viewer" "$OUT"
  run "$APIGEE" --yes role create ops
  assert_status "create" 0
  assert_contains "create body" "$(curl_log)" '"role":[{"name":"ops"}]'
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes role add-user ops a@b.com
  assert_status "add-user" 0
  assert_contains "url" "$(curl_log)" "/userroles/ops/users?id=a%40b.com"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes role remove-user ops a@b.com
  assert_contains "remove" "$(curl_log)" "=== DELETE"
  assert_contains "remove url" "$(curl_log)" "/userroles/ops/users/a%40b.com"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes role delete ops
  assert_contains "delete url" "$(curl_log)" "/userroles/ops"
}

test_role_users_and_permissions() {
  use_edge
  route GET '/userroles/ops/users$' 200 '["a@b.com"]'
  route GET '/userroles/ops/permissions$' 200 '{"resourcePermission":[{"path":"/apis","permissions":["get"]}]}'
  run "$APIGEE" role users ops
  assert_eq "users" "a@b.com" "$OUT"
  run "$APIGEE" role permissions ops
  assert_contains "perm" "$OUT" '"path": "/apis"'
}

test_env_create_and_delete() {
  use_x
  run "$APIGEE" --yes env create newenv
  assert_status "create" 0
  assert_contains "url" "$(curl_log)" "/organizations/org1/environments"
  assert_contains "body" "$(curl_log)" '"name":"newenv"'
  run "$APIGEE" --yes env delete newenv
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
  assert_contains "del url" "$(curl_log)" "/organizations/org1/environments/newenv"
}

test_env_delete_confirms() {
  use_edge
  run "$APIGEE" env delete newenv
  assert_status "no yes" 1
  assert_eq "no DELETE" "" "$(grep '^=== DELETE' "$FAKE_CURL_LOG")"
}

test_org_delete_is_opdk_only_and_needs_typed_name() {
  use_edge
  run "$APIGEE" --yes org delete --confirm-name org1
  assert_status "edge refused" 1
  use_opdk
  run "$APIGEE" --yes org delete
  assert_status "needs --confirm-name" 1
  run "$APIGEE" --yes org delete --confirm-name wrong
  assert_status "wrong name" 1
  assert_eq "nothing sent" "" "$(grep '^=== DELETE' "$FAKE_CURL_LOG")"
  run "$APIGEE" --yes org delete --confirm-name org1
  assert_status "delete" 0
  assert_contains "DELETE org" "$(curl_log)" "=== DELETE http://opdk.example.com:8080/v1/organizations/org1"
}

test_org_delete_dry_run_sends_nothing() {
  use_opdk
  run "$APIGEE" --dry-run org delete --confirm-name org1
  assert_status "dry" 0
  assert_contains "plan" "$OUT$ERR" "DRY-RUN: DELETE"
  assert_eq "no real request" "" "$(grep '^=== DELETE' "$FAKE_CURL_LOG")"
}

test_proxy_delete_refuses_deployed() {
  use_x
  route GET '/apis/p1/deployments$' 200 '{"deployments":[{"environment":"test","apiProxy":"p1","revision":"2"}]}'
  run "$APIGEE" --yes proxy delete p1
  assert_status "deployed" 1
  assert_contains "why" "$ERR" "deployed"
  assert_eq "no DELETE" "" "$(grep '^=== DELETE' "$FAKE_CURL_LOG")"
}

test_proxy_delete_when_undeployed() {
  use_x
  route GET '/apis/p1/deployments$' 200 '{}'
  run "$APIGEE" --yes proxy delete p1
  assert_status "delete" 0
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
  assert_contains "url" "$(curl_log)" "/organizations/org1/apis/p1"
}

test_resourcefile_verbs() {
  use_edge
  route GET "/environments/test/resourcefiles\$" 200 '{"resourceFile":[{"name":"a.js","type":"jsc"},{"name":"b.xsl","type":"xsl"}]}'
  run "$APIGEE" resourcefile list
  assert_status "list" 0
  assert_eq "pairs" "jsc a.js
xsl b.xsl" "$OUT"
  route GET "/resourcefiles/jsc/a.js\$" 200 'var x=1;'
  run "$APIGEE" resourcefile get jsc a.js
  assert_eq "content" 'var x=1;' "$OUT"
  printf 'var y=2;' >"$T/y.js"
  run "$APIGEE" --yes resourcefile upload jsc "$T/y.js"
  assert_status "upload" 0
  assert_contains "url" "$(curl_log)" "resourcefiles?name=y.js&type=jsc"
  assert_contains "form" "$(curl_log)" "file=@$T/y.js"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes resourcefile delete jsc a.js
  assert_contains "del" "$(curl_log)" "=== DELETE"
  assert_contains "del url" "$(curl_log)" "/resourcefiles/jsc/a.js"
}

test_resourcefile_org_scope_and_revision() {
  use_edge
  route GET "/organizations/org1/resourcefiles\$" 200 '{"resourceFile":[{"name":"o.js","type":"jsc"}]}'
  run "$APIGEE" resourcefile list --scope org
  assert_eq "org list" "jsc o.js" "$OUT"
  route GET "/apis/p1/revisions/3/resources\$" 200 '["jsc://a.js","xsl://b.xsl"]'
  run "$APIGEE" resourcefile revision p1 3
  assert_eq "revision" "jsc://a.js
xsl://b.xsl" "$OUT"
}

run_tests
