#!/usr/bin/env bash
# lib/json.sh operations. tests/run.sh runs this once per engine (jq, python).
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# json OP [ARGS...] < stdin
json() {
  APIGEE_TOOLKIT_HOME="$ROOT" bash -c '
    apigee_die() { printf "%s\n" "$*" >&2; exit 1; }
    . "$APIGEE_TOOLKIT_HOME/lib/json.sh"
    apigee_json "$@"' _ "$@"
}

jrun() {
  local input="$1"
  shift
  printf '%s' "$input" | json "$@" >"$T/out" 2>"$T/err"
  STATUS=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}

test_pretty() {
  jrun '{"a":1}' pretty
  assert_status "pretty" 0
  assert_eq "pretty" '{
  "a": 1
}' "$OUT"
}

test_names_from_list_and_wrapped_object() {
  jrun '["b","a"]' names
  assert_eq "plain list" "b
a" "$OUT"
  jrun '{"developer":[{"email":"d@x.com"},{"name":"n1"}]}' names
  assert_eq "wrapped" "d@x.com
n1" "$OUT"
  jrun '{"aliases":["k1","k2"],"x":1}' names aliases
  assert_eq "field" "k1
k2" "$OUT"
  jrun '{}' names
  assert_eq "empty" "" "$OUT"
}

test_get_and_get_raw() {
  jrun '{"a":{"b":"v"},"n":null,"o":{"k":1}}' get a.b
  assert_eq "nested" "v" "$OUT"
  jrun '{"n":null}' get n
  assert_eq "null is empty" "" "$OUT"
  jrun '{"a":{"b":"v"}}' get missing.path
  assert_eq "missing is empty" "" "$OUT"
  jrun '{"o":{"k":1}}' get o
  assert_eq "object as json" '{"k":1}' "$(printf '%s' "$OUT" | tr -d ' \n')"
  jrun '{"a":"v"}' get-raw a
  assert_eq "raw has no newline" "v" "$(cat "$T/out")"
}

test_merge_is_deep() {
  jrun '{"a":{"x":1,"y":2},"keep":true}' merge '{"a":{"y":3},"new":1}'
  assert_status "merge" 0
  assert_eq "x kept" "1" "$(printf '%s' "$OUT" | jq -r .a.x)"
  assert_eq "y overridden" "3" "$(printf '%s' "$OUT" | jq -r .a.y)"
  assert_eq "keep" "true" "$(printf '%s' "$OUT" | jq -r .keep)"
  assert_eq "new" "1" "$(printf '%s' "$OUT" | jq -r .new)"
}

test_build_types() {
  jrun '' build 'name=ts' 'port:=8080' 'on:=true' 'obj:={"k":1}' 'eq=a=b'
  assert_status "build" 0
  assert_eq "string" "ts" "$(printf '%s' "$OUT" | jq -r .name)"
  assert_eq "number" "number" "$(printf '%s' "$OUT" | jq -r '.port | type')"
  assert_eq "bool" "boolean" "$(printf '%s' "$OUT" | jq -r '.on | type')"
  assert_eq "object" "1" "$(printf '%s' "$OUT" | jq -r .obj.k)"
  assert_eq "value containing =" "a=b" "$(printf '%s' "$OUT" | jq -r .eq)"
  jrun '' build
  assert_eq "empty build" "{}" "$(printf '%s' "$OUT" | tr -d ' \n')"
}

test_deployed_revs_x_and_edge() {
  jrun '{"deployments":[{"revision":"2"},{"revision":"5"}]}' deployed-revs
  assert_eq "x" "2
5" "$OUT"
  jrun '{"revision":[{"name":"1"},{"name":"4"}]}' deployed-revs
  assert_eq "edge" "1
4" "$OUT"
}

test_deployed_all() {
  jrun '{"deployments":[{"environment":"dev","revision":"2"}]}' deployed-all
  assert_eq "x" "dev 2" "$OUT"
  jrun '{"environment":[{"name":"prod","revision":[{"name":"7"}]}]}' deployed-all
  assert_eq "edge" "prod 7" "$OUT"
}

test_env_deployments() {
  jrun '{"deployments":[{"apiProxy":"p","revision":"3","state":"READY"},{"sharedFlow":"s","revision":"1"}]}' env-deployments
  assert_eq "x" "p 3 READY
s 1 deployed" "$OUT"
  jrun '{"aPIProxy":[{"name":"p","revision":[{"name":"2","state":"deployed"}]}]}' env-deployments
  assert_eq "edge" "p 2 deployed" "$OUT"
}

test_kvm_entry_formats() {
  jrun '{"keyValueEntries":[{"name":"a","value":"1"},{"name":"b","value":"2"}]}' kvm-entries
  assert_eq "keyValueEntries" '{"name":"a","value":"1"}
{"name":"b","value":"2"}' "$OUT"
  jrun '{"entry":[{"name":"a","value":"1","extra":"x"}]}' kvm-entries
  assert_eq "edge entry, extras dropped" '{"name":"a","value":"1"}' "$OUT"
  jrun '{"entries":[{"name":"a","value":"1"}]}' kvm-entries
  assert_eq "entries" '{"name":"a","value":"1"}' "$OUT"
}

test_kvm_doc_and_lines_roundtrip() {
  jrun '{"name":"a","value":"1"}
{"name":"b","value":"semi;colon"}' kvm-doc map1 true
  assert_status "kvm-doc" 0
  assert_eq "name" "map1" "$(printf '%s' "$OUT" | jq -r .name)"
  assert_eq "encrypted" "true" "$(printf '%s' "$OUT" | jq -r .encrypted)"
  assert_eq "entries" "2" "$(printf '%s' "$OUT" | jq '.entries | length')"
  jrun '{"name":"a","value":"1"}
{"name":"b","value":"x"}' entries-to-lines
  assert_eq "lines" "a;1
b;x" "$OUT"
}

test_kvm_entry_keeps_value_verbatim() {
  local pem=$'-----BEGIN X-----\nabc "q" \\ \n-----END X-----'
  jrun "$pem" kvm-entry cert
  assert_eq "value preserved" "$pem" "$(printf '%s' "$OUT" | jq -r .value)"
  assert_eq "name" "cert" "$(printf '%s' "$OUT" | jq -r .name)"
}

test_masked_keys() {
  jrun '{"name":"a","value":"********"}
{"name":"b","value":"real"}
{"name":"c","value":"a*"}
{"name":"d","value":""}' masked-keys
  assert_eq "only all-asterisk values" "a" "$OUT"
}

test_app_statuses() {
  jrun '{"app":[{"name":"x","status":"Pending"},{"name":"y"},{"name":"z","status":""}]}' app-statuses
  assert_eq "wrapped" "pending x
- y
- z" "$OUT"
  jrun '[{"name":"x","status":"REVOKED"}]' app-statuses
  assert_eq "plain list" "revoked x" "$OUT"
}

test_unknown_op_fails() {
  jrun '{}' no-such-op
  [[ "$STATUS" != 0 ]] || fail "unknown op should exit non-zero"
}

test_json_string_escaping() {
  local out
  out="$(bash -c '. "$1/lib/json.sh"; apigee_json_string "$2"' _ "$ROOT" $'a"b\\c\nd\te')"
  assert_eq "escaped" '"a\"b\\c\nd\te"' "$out"
  assert_eq "valid json" $'a"b\\c\nd\te' "$(printf '%s' "$out" | jq -r .)"
}

run_tests
