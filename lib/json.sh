# shellcheck shell=bash
#
# JSON helpers. Uses jq when available, otherwise lib/jsontool.py (python3).
# Force an engine with APIGEE_JSON_ENGINE=jq|python.
#
#   apigee_json pretty                 pretty-print stdin
#   apigee_json names [FIELD]          one name per line from a list response
#   apigee_json get PATH               scalar at dotted PATH (empty if null)
#   apigee_json get-raw PATH           like get, but no trailing newline is added
#   apigee_json merge OVERRIDE_JSON    deep-merge OVERRIDE_JSON into stdin
#   apigee_json build k=v k:=json ...  build an object (non-secret values only)
#   apigee_json deployed-revs          revisions deployed in one environment
#   apigee_json deployed-all           "env revision" lines across environments
#   apigee_json env-deployments        "name revision state" lines for an env
#   apigee_json kvm-entries            compact {"name","value"} JSON lines
#   apigee_json kvm-doc NAME ENC       entries JSON lines -> export document
#   apigee_json kvm-entry NAME         stdin is the raw value -> entry JSON
#   apigee_json entries-to-lines       entries JSON lines -> "name;value"
#   apigee_json masked-keys            names of entries whose value is all asterisks
#   apigee_json app-statuses           "status name" per app (status lowercased, "-" if unset)

apigee_json_engine() {
  case "${APIGEE_JSON_ENGINE:-auto}" in
    jq) printf 'jq\n' ;;
    python) printf 'python\n' ;;
    auto)
      if command -v jq >/dev/null 2>&1; then
        printf 'jq\n'
      elif command -v python3 >/dev/null 2>&1; then
        printf 'python\n'
      else
        apigee_die "need jq or python3 for JSON processing (run setup/install.sh)"
      fi
      ;;
    *) apigee_die "unsupported APIGEE_JSON_ENGINE '${APIGEE_JSON_ENGINE}'" ;;
  esac
}

apigee_json() {
  local op="$1"
  shift
  if [[ "$(apigee_json_engine)" == python ]]; then
    python3 "$APIGEE_TOOLKIT_HOME/lib/jsontool.py" "$op" "$@"
    return
  fi
  local names_expr='(if type == "object" then (.name // .email // .appId // .aliasName // .id // empty) else . end) | tostring'
  case "$op" in
    pretty) jq . ;;
    names)
      if [[ -n "${1:-}" ]]; then
        jq -r --arg f "$1" "(.[\$f] // [])[] | $names_expr"
      else
        jq -r "(if type == \"array\" then . elif type == \"object\" then ([.[] | select(type == \"array\")] | first // []) else [] end)[] | $names_expr"
      fi
      ;;
    get) jq -r --arg p "$1" 'getpath($p | split(".")) | if . == null then empty elif type == "object" or type == "array" then tojson else tostring end' ;;
    get-raw) jq -j --arg p "$1" 'getpath($p | split(".")) | if . == null then empty elif type == "object" or type == "array" then tojson else tostring end' ;;
    merge) jq --argjson o "$1" '. * $o' ;;
    build)
      jq -n '[$ARGS.positional[] | capture("^(?<k>[^:=]+)(?<t>:?=)(?<v>.*)$"; "s")
              | {(.k): (if .t == ":=" then (.v | fromjson) else .v end)}] | add // {}' --args "$@"
      ;;
    deployed-revs) jq -r '((.revision // [])[] | .name), ((.deployments // [])[] | .revision) | tostring' ;;
    deployed-all)
      jq -r '((.environment // [])[] | .name as $e | (.revision // [])[] | "\($e) \(.name)"),
             ((.deployments // [])[] | "\(.environment) \(.revision)")'
      ;;
    env-deployments)
      jq -r '((.aPIProxy // [])[] | .name as $n | (.revision // [])[] | "\($n) \(.name) \(.state // "unknown")"),
             ((.deployments // [])[] | "\(.apiProxy // .sharedFlow // "?") \(.revision) \(.state // "deployed")")'
      ;;
    kvm-entries) jq -c '(.entries // .entry // .keyValueEntries // [])[] | {name, value}' ;;
    kvm-doc) jq -s --arg n "$1" --argjson e "${2:-true}" '{name: $n, encrypted: $e, entries: .}' ;;
    kvm-entry) jq -cRs --arg n "$1" '{name: $n, value: .}' ;;
    entries-to-lines) jq -r '"\(.name);\(.value)"' ;;
    masked-keys) jq -r 'select((.value | type) == "string" and (.value | test("\\A\\*+\\z"))) | .name | tostring' ;;
    app-statuses)
      jq -r '(if type == "array" then . else (.app // []) end)[] | select(type == "object")
             | "\(if (.status | type) == "string" and .status != "" then (.status | ascii_downcase) else "-" end) \(.name)"'
      ;;
    *) apigee_die "apigee_json: unknown op '$op'" ;;
  esac
}

# Encode a bash string as a JSON string literal (pure bash; used by the
# legacy "key;value" parser so no secret ever reaches a child's argv).
apigee_json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}
