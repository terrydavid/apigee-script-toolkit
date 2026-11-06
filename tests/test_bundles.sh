#!/usr/bin/env bash
# Proxy / shared flow revision logic on both platforms.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

test_latest_and_deployed_x() {
  use_x
  route GET '/apis/p1/revisions$' 200 '["1","10","2"]'
  route GET '/environments/test/apis/p1/deployments$' 200 '{"deployments":[{"environment":"test","apiProxy":"p1","revision":"2"}]}'
  run "$APIGEE" proxy latest p1
  assert_eq "numeric max" "10" "$OUT"
  run "$APIGEE" proxy deployed p1
  assert_eq "deployed" "2" "$OUT"
}

test_deployed_edge_and_not_deployed() {
  use_edge
  route GET '/environments/test/sharedflows/sf1/deployments$' 200 '{"name":"sf1","revision":[{"name":"4","state":"deployed"}]}'
  route GET '/environments/test/sharedflows/sf2/deployments$' 400 '{"code":"distribution.ApplicationNotDeployed"}'
  run "$APIGEE" sharedflow deployed sf1
  assert_eq "edge deployed" "4" "$OUT"
  run "$APIGEE" sharedflow deployed sf2
  assert_status "not deployed is not an error" 0
  assert_eq "empty" "" "$OUT"
}

test_deployed_all_envs_both_formats() {
  use_edge
  route GET '/organizations/org1/apis/p1/deployments$' 200 '{"environment":[{"name":"prod","revision":[{"name":"3"}]},{"name":"test","revision":[{"name":"5"}]}]}'
  run "$APIGEE" proxy deployed p1 --all-envs
  assert_eq "edge" "prod 3
test 5" "$OUT"
  use_x
  : >"$FAKE_CURL_ROUTES"
  route GET '/organizations/org1/apis/p1/deployments$' 200 '{"deployments":[{"environment":"prod","revision":"3"}]}'
  run "$APIGEE" proxy deployed p1 --all-envs
  assert_eq "x" "prod 3" "$OUT"
}

test_deployed_flags_work_in_any_position() {
  use_edge
  route GET '/organizations/org1/apis/p1/deployments$' 200 '{"environment":[{"name":"prod","revision":[{"name":"3"}]}]}'
  route GET '/environments/test/apis/p1/deployments$' 200 '{"name":"p1","revision":[{"name":"2"}]}'
  run "$APIGEE" proxy deployed --all-envs p1
  assert_status "flag first" 0
  assert_eq "flag before name" "prod 3" "$OUT"
  run "$APIGEE" proxy deployed p1
  assert_eq "env only" "2" "$OUT"
  run "$APIGEE" proxy deployed --all-envs
  assert_status "no name" 1
  assert_contains "missing name" "$ERR" "missing NAME"
  run "$APIGEE" proxy deployed --bogus p1
  assert_status "unknown flag" 1
  assert_contains "unknown option" "$ERR" "unknown option --bogus"
  run "$APIGEE" proxy latest --all-envs
  assert_status "option is not a name" 1
  assert_contains "latest rejects option" "$ERR" "unknown option --all-envs"
}

test_clean_revisions_keeps_newest_and_deployed() {
  use_x
  route GET '/apis/p1/revisions$' 200 '["1","2","3","4","5","6","7"]'
  route GET '/organizations/org1/apis/p1/deployments$' 200 '{"deployments":[{"environment":"prod","revision":"2"}]}'
  run "$APIGEE" --dry-run proxy clean-revisions p1 --keep 3
  assert_status "clean" 0
  local deletes
  deletes="$(printf '%s\n' "$OUT" | grep 'DRY-RUN: DELETE' | sed 's#.*/revisions/##')"
  assert_eq "deletes 1,3,4 only" "1
3
4" "$deletes"
}

test_delete_revision_expands_ranges_and_skips_deployed() {
  use_edge
  route GET '/organizations/org1/sharedflows/sf1/deployments$' 200 '{"environment":[{"name":"test","revision":[{"name":"4"}]}]}'
  run "$APIGEE" --yes sharedflow delete-revision sf1 3-5 8
  assert_status "delete" 0
  assert_contains "skip deployed" "$ERR" "skipping sharedflow sf1 revision 4"
  local deletes
  deletes="$(grep '^=== DELETE' "$FAKE_CURL_LOG" | sed 's#.*/revisions/##')"
  assert_eq "deleted" "3
5
8" "$deletes"
}

test_undeploy_defaults_to_deployed_revision() {
  use_x
  route GET '/environments/test/apis/p1/deployments$' 200 '{"deployments":[{"revision":"6"}]}'
  run "$APIGEE" --yes proxy undeploy p1
  assert_status "undeploy" 0
  assert_contains "delete deployment" "$(curl_log)" "=== DELETE https://apigee.googleapis.com/v1/organizations/org1/environments/test/apis/p1/revisions/6/deployments"
}

test_deploy_edge_override_and_service_account_x_only() {
  use_edge
  run "$APIGEE" --yes proxy deploy p1 3
  assert_status "deploy" 0
  assert_contains "edge deploy" "$(curl_log)" "=== POST https://api.enterprise.apigee.com/v1/organizations/org1/environments/test/apis/p1/revisions/3/deployments?override=true"
  assert_contains "form content type" "$(curl_log)" "header: Content-Type: application/x-www-form-urlencoded"
  run "$APIGEE" --yes proxy deploy p1 3 --service-account sa@example.com
  assert_status "sa on edge" 1
  assert_contains "sa msg" "$ERR" "not supported on Apigee Edge"
}

test_import_zips_directory() {
  use_x
  mkdir -p "$T/src/apiproxy/policies"
  printf '<APIProxy name="p1"/>' >"$T/src/apiproxy/p1.xml"
  route POST '/organizations/org1/apis\?action=import&name=p1&validate=true$' 200 '{"name":"p1","revision":"8"}'
  run "$APIGEE" --yes proxy import p1 "$T/src" --validate
  assert_status "import" 0
  assert_eq "new revision" "8" "$OUT"
  assert_contains "multipart" "$(curl_log)" "form: file=@"
  run "$APIGEE" --yes proxy import p1 "$T/src/apiproxy/policies"
  assert_status "bad dir" 1
}

test_compare_two_revisions() {
  use_x
  command -v zip >/dev/null && command -v unzip >/dev/null || return 0
  mkdir -p "$T/r1/apiproxy" "$T/r2/apiproxy"
  printf 'a\n' >"$T/r1/apiproxy/x.xml"
  printf 'b\n' >"$T/r2/apiproxy/x.xml"
  (cd "$T/r1" && zip -qr "$T/r1.zip" apiproxy)
  (cd "$T/r2" && zip -qr "$T/r2.zip" apiproxy)
  printf '%s %s %s %s\n' GET '/apis/p1/revisions/1\?format=bundle$' 200 "$T/r1.zip" >>"$FAKE_CURL_ROUTES"
  printf '%s %s %s %s\n' GET '/apis/p1/revisions/2\?format=bundle$' 200 "$T/r2.zip" >>"$FAKE_CURL_ROUTES"
  run "$APIGEE" proxy compare p1 1 2
  assert_status "differs" 1
  assert_contains "diff" "$OUT" "-a"
  assert_contains "diff" "$OUT" "+b"
  run "$APIGEE" proxy compare p1 1 --dir "$T/r1"
  assert_status "same as local" 0
}

run_tests
