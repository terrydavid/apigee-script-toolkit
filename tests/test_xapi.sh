#!/usr/bin/env bash
# apigeecli equivalents (Apigee X / hybrid): generic org/env collections, flowhooks,
# debug sessions, IAM, sync identities, key aliases, debug masks, proxy export.
. "$(dirname "$0")/lib.sh"

ORGP='/organizations/org1'
ENVP='/organizations/org1/environments/test'

test_xapi_resources_refuse_edge() {
  local r
  use_edge
  for r in appgroup datacollector datastore reference securityprofile site endpoint operation flowhook trace iam sync; do
    run "$APIGEE" "$r" get
    assert_status "$r on edge" 1
    assert_contains "$r why" "$ERR" "Apigee X"
  done
}

test_collection_paths_and_verbs() {
  local spec r path
  use_x
  for spec in "appgroup:$ORGP/appgroups" "datacollector:$ORGP/datacollectors" "datastore:$ORGP/analytics/datastores" \
              "reference:$ENVP/references" "securityprofile:$ORGP/securityProfiles" "site:$ORGP/sites" "endpoint:$ORGP/endpointAttachments"; do
    r="${spec%%:*}"; path="${spec#*:}"
    : >"$FAKE_CURL_LOG"
    run "$APIGEE" "$r" get x1
    assert_status "$r get" 0
    assert_contains "$r get url" "$(curl_log)" "=== GET https://apigee.googleapis.com/v1$path/x1"
    : >"$FAKE_CURL_LOG"
    run "$APIGEE" --yes "$r" create x1 --description "d d"
    assert_status "$r create" 0
    assert_contains "$r create url" "$(curl_log)" "=== POST https://apigee.googleapis.com/v1$path"
    assert_contains "$r create body" "$(curl_log)" '"name":"x1"'
    assert_contains "$r desc" "$(curl_log)" '"description":"d d"'
    : >"$FAKE_CURL_LOG"
    run "$APIGEE" --yes "$r" delete x1
    assert_status "$r delete" 0
    assert_contains "$r delete url" "$(curl_log)" "=== DELETE https://apigee.googleapis.com/v1$path/x1"
    run "$APIGEE" "$r" delete x1
    assert_status "$r delete needs yes" 1
  done
}

test_collection_list_names_and_update() {
  use_x
  route GET "$ORGP/datacollectors\$" 200 '{"dataCollectors":[{"name":"dc2"},{"name":"dc1"}]}'
  run "$APIGEE" datacollector list
  assert_eq "names" "dc1
dc2" "$OUT"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes datacollector update dc1 --json '{"description":"new"}'
  assert_status "update" 0
  assert_contains "PATCH" "$(curl_log)" "=== PATCH"
  assert_contains "url" "$(curl_log)" "$ORGP/datacollectors/dc1"
}

test_create_from_file_and_reference_options() {
  use_x
  printf '{"name":"r1","refers":"ks","resourceType":"KeyStore"}' >"$T/r.json"
  run "$APIGEE" --yes reference create --from-file "$T/r.json"
  assert_status "from file" 0
  assert_contains "body" "$(curl_log)" '"refers":"ks"'
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes reference create r2 --refers ks2 --resource-type KeyStore
  assert_contains "refers" "$(curl_log)" '"refers":"ks2"'
  assert_contains "type" "$(curl_log)" '"resourceType":"KeyStore"'
}

test_operation_is_read_only() {
  use_x
  run "$APIGEE" --yes operation delete op1
  assert_status "no delete" 1
  run "$APIGEE" operation get op1
  assert_status "get" 0
  assert_contains "url" "$(curl_log)" "$ORGP/operations/op1"
}

test_apidoc_and_apicategory_need_site() {
  use_x
  run "$APIGEE" apidoc list
  assert_status "no site" 1
  assert_contains "why" "$ERR" "--site"
  run "$APIGEE" apidoc list --site portal1
  assert_status "list" 0
  assert_contains "url" "$(curl_log)" "$ORGP/sites/portal1/apidocs"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" apicategory get c1 --site portal1
  assert_contains "cat url" "$(curl_log)" "$ORGP/sites/portal1/apicategories/c1"
}

test_flowhook_attach_detach() {
  use_x
  route GET "$ENVP/flowhooks\$" 200 '[{"name":"PreProxyFlowHook"},{"name":"PostProxyFlowHook"}]'
  run "$APIGEE" flowhook list
  assert_status "list" 0
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" flowhook get PreProxyFlowHook
  assert_contains "get" "$(curl_log)" "$ENVP/flowhooks/PreProxyFlowHook"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes flowhook attach PreProxyFlowHook --sharedflow sf1 --continue-on-error
  assert_status "attach" 0
  assert_contains "PUT" "$(curl_log)" "=== PUT"
  assert_contains "sf" "$(curl_log)" '"sharedFlow":"sf1"'
  assert_contains "coe" "$(curl_log)" '"continueOnError":true'
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes flowhook detach PreProxyFlowHook
  assert_contains "DELETE" "$(curl_log)" "=== DELETE"
  run "$APIGEE" --yes flowhook attach BogusHook --sharedflow sf1
  assert_status "bad point" 1
}

test_trace_sessions() {
  use_x
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes trace create p1 3 --session s1 --filter a=1 --filter b=2
  assert_status "create" 0
  assert_contains "url" "$(curl_log)" "$ENVP/apis/p1/revisions/3/debugsessions?session=s1"
  assert_contains "filter" "$(curl_log)" 'a=1'
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" trace list p1 3
  assert_contains "list" "$(curl_log)" "$ENVP/apis/p1/revisions/3/debugsessions"
  run "$APIGEE" trace data p1 3 s1
  assert_contains "data" "$(curl_log)" "debugsessions/s1/data"
  run "$APIGEE" --yes trace delete p1 3 s1
  assert_contains "delete" "$(curl_log)" "=== DELETE"
}

test_iam_get_and_set() {
  use_x
  run "$APIGEE" iam get
  assert_status "org get" 0
  assert_contains "org url" "$(curl_log)" "$ORGP:getIamPolicy"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" iam get --scope env
  assert_contains "env url" "$(curl_log)" "$ENVP:getIamPolicy"
  printf '{"policy":{"bindings":[]}}' >"$T/p.json"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes iam set --scope env --from-file "$T/p.json"
  assert_status "set" 0
  assert_contains "set url" "$(curl_log)" "$ENVP:setIamPolicy"
  run "$APIGEE" iam set --from-file "$T/p.json"
  assert_status "set needs yes" 1
}

test_sync_identities() {
  use_x
  route POST "$ORGP:getSyncAuthorization\$" 200 '{"identities":["serviceAccount:a@p.iam"],"etag":"E1"}'
  run "$APIGEE" sync get
  assert_status "get" 0
  assert_contains "id" "$OUT" "a@p.iam"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes sync add serviceAccount:b@p.iam
  assert_status "add" 0
  assert_contains "set url" "$(curl_log)" "$ORGP:setSyncAuthorization"
  assert_contains "both identities" "$(curl_log)" '"serviceAccount:b@p.iam"'
  assert_contains "keeps existing" "$(curl_log)" '"serviceAccount:a@p.iam"'
  assert_contains "etag" "$(curl_log)" '"etag":"E1"'
}

test_keystore_alias_verbs() {
  use_x
  route GET "$ENVP/keystores/ks1/aliases\$" 200 '["a2","a1"]'
  run "$APIGEE" keystore aliases ks1
  assert_eq "aliases sorted" "a1
a2" "$OUT"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" keystore alias-get ks1 a1
  assert_contains "get" "$(curl_log)" "keystores/ks1/aliases/a1"
  run "$APIGEE" keystore cert ks1 a1
  assert_contains "cert" "$(curl_log)" "keystores/ks1/aliases/a1/certificate"
  run "$APIGEE" keystore csr ks1 a1
  assert_contains "csr" "$(curl_log)" "keystores/ks1/aliases/a1/csr"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes keystore alias-delete ks1 a1
  assert_contains "delete" "$(curl_log)" "=== DELETE"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes keystore self-signed ks1 --alias s1 --common-name example.com --days 365
  assert_status "self-signed" 0
  assert_contains "url" "$(curl_log)" "aliases?alias=s1&format=selfsignedcert"
  assert_contains "cn" "$(curl_log)" '"commonName":"example.com"'
  assert_contains "days" "$(curl_log)" '"certValidityInDays":"365"'
}

test_env_debugmask() {
  use_x
  route GET "$ENVP/debugmask\$" 200 '{"name":"organizations/org1/environments/test/debugmask","requestXPathExpressions":[]}'
  run "$APIGEE" env debugmask get
  assert_status "get" 0
  assert_contains "json" "$OUT" "requestXPathExpressions"
  printf '{"requestXPathExpressions":["/a"]}' >"$T/m.json"
  : >"$FAKE_CURL_LOG"
  run "$APIGEE" --yes env debugmask set --from-file "$T/m.json"
  assert_status "set" 0
  assert_contains "PATCH" "$(curl_log)" "=== PATCH"
  assert_contains "url" "$(curl_log)" "$ENVP/debugmask"
}

test_proxy_export_downloads_latest_of_each() {
  use_x
  route GET "$ORGP/apis\$" 200 '{"proxies":[{"name":"p1"},{"name":"p2"}]}'
  route GET "$ORGP/apis/p1/revisions\$" 200 '["1","2"]'
  route GET "$ORGP/apis/p2/revisions\$" 200 '["5"]'
  run "$APIGEE" proxy export --dir "$T/exp"
  assert_status "export" 0
  assert_contains "p1 rev 2" "$(curl_log)" "apis/p1/revisions/2?format=bundle"
  assert_contains "p2 rev 5" "$(curl_log)" "apis/p2/revisions/5?format=bundle"
  [[ -f "$T/exp/p1-rev2.zip" ]] || fail "p1 zip written"
}

run_tests
