# shellcheck shell=bash
#
# Analytics, read-only:
#   apigee stats traffic FROM TO [--by DIMENSION] [--select EXPR] [--time-unit UNIT]
#   apigee stats query DIMENSIONS --select EXPR --range FROM TO [--filter F] [--limit N] [--time-unit UNIT]
#   apigee report list|get ID           (saved custom reports)
#
# Replaces the legacy getRptTraffic, getRptTrafficMonth, getReport, getStats and
# getAnals. Dates are YYYY-MM-DD (midnight); the API wants MM/dd/yyyy HH:mm.

stats_verbs() { printf '%s\n' traffic query; }
report_verbs() { printf '%s\n' list get; }

stats_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee stats <verb>   (read-only; uses --env)\n\nVerbs:\n  traffic FROM TO    Messages, errors and TPS per proxy for a date range\n  query DIMENSIONS   Any analytics query (--select and --range required)\n\nDates are YYYY-MM-DD. Run '"'"'apigee stats <verb> --help'"'"' for details.\n' ;;
    traffic) printf 'Usage: apigee stats traffic FROM TO [--by DIMENSION] [--select EXPR] [--time-unit UNIT]\n\nTraffic for --env between FROM and TO (YYYY-MM-DD, midnight to midnight).\nDefaults: --by apiproxy, --select "sum(message_count),sum(is_error),tps".\nExample: apigee stats traffic 2026-11-01 2026-11-19 --by developer_app --time-unit day\n' ;;
    query) printf 'Usage: apigee stats query DIMENSIONS --select EXPR --range FROM TO [--filter F] [--limit N] [--time-unit UNIT] [--sort ASC|DESC] [--sortby EXPR]\n\nRun a stats query against --env. DIMENSIONS is comma-separated (apiproxy,response_status_code).\nExample: apigee stats query apiproxy --select "sum(message_count)" --range 2026-11-01 2026-11-02\n' ;;
    *) apigee_die "unknown stats verb '$1'" ;;
  esac
}

report_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee report <verb>   (read-only)\n\nVerbs:\n  list     List saved custom reports of the organization\n  get ID   Show one custom report definition\n' ;;
    list) printf 'Usage: apigee report list\n\nList the saved custom reports of the organization.\n' ;;
    get) printf 'Usage: apigee report get ID\n\nShow the definition of one saved custom report.\n' ;;
    *) apigee_die "unknown report verb '$1'" ;;
  esac
}

# YYYY-MM-DD -> "MM/dd/yyyy 00:00"
stats_date() {
  [[ "$1" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]] || apigee_die "bad date '$1': use YYYY-MM-DD"
  printf '%s/%s/%s 00:00' "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[1]}"
}

stats_run() { # dimensions select from to [extra query string pairs...]
  local dims="$1" sel="$2" from="$3" to="$4" q f t
  shift 4
  f="$(stats_date "$from")" || exit 1
  t="$(stats_date "$to")" || exit 1
  q="select=$(apigee_urlencode "$sel")&timeRange=$(apigee_urlencode "$f~$t")"
  while (($#)); do
    q="$q&$1=$(apigee_urlencode "$2")"
    shift 2
  done
  apigee_get "$(apigee_env_path)/stats/$(apigee_urlencode "$dims")?$q" | apigee_json pretty
}

stats_main() {
  local verb="${1:-}"
  shift || true
  local by=apiproxy sel="" from="" to="" extra=() pos=() dims=""
  case "$verb" in
    traffic | query)
      while (($#)); do
        case "$1" in
          --by) by="${2:?--by needs a value}"; shift 2 ;;
          --select) sel="${2:?--select needs a value}"; shift 2 ;;
          --range) from="${2:-}"; to="${3:-}"; [[ -n "$from" && -n "$to" ]] || apigee_die "--range needs FROM TO"; shift 3 ;;
          --time-unit) extra+=(timeUnit "${2:?--time-unit needs a value}"); shift 2 ;;
          --filter) extra+=(filter "${2:?--filter needs a value}"); shift 2 ;;
          --limit) extra+=(limit "${2:?--limit needs a value}"); shift 2 ;;
          --sort) extra+=(sort "${2:?--sort needs a value}"); shift 2 ;;
          --sortby) extra+=(sortby "${2:?--sortby needs a value}"); shift 2 ;;
          -*) apigee_die "unknown option $1 (see 'apigee stats $verb --help')" ;;
          *) pos+=("$1"); shift ;;
        esac
      done
      ;;
  esac
  case "$verb" in
    traffic)
      ((${#pos[@]} == 2)) || apigee_die "usage: apigee stats traffic FROM TO (YYYY-MM-DD)"
      [[ -n "$sel" ]] || sel="sum(message_count),sum(is_error),tps"
      stats_run "$by" "$sel" "${pos[0]}" "${pos[1]}" ${extra[@]+"${extra[@]}"}
      ;;
    query)
      ((${#pos[@]} == 1)) || apigee_die "usage: apigee stats query DIMENSIONS --select EXPR --range FROM TO"
      dims="${pos[0]}"
      [[ -n "$sel" ]] || apigee_die "stats query needs --select EXPR"
      [[ -n "$from" ]] || apigee_die "stats query needs --range FROM TO"
      stats_run "$dims" "$sel" "$from" "$to" ${extra[@]+"${extra[@]}"}
      ;;
    *) apigee_die "unknown stats verb '$verb' (see 'apigee stats --help')" ;;
  esac
}

report_main() {
  case "${1:-}" in
    list) apigee_get "$(apigee_org_path)/reports" | apigee_json pretty ;;
    get)
      [[ -n "${2:-}" ]] || apigee_die "missing ID"
      apigee_get "$(apigee_org_path)/reports/$(apigee_urlencode "$2")" | apigee_json pretty
      ;;
    *) apigee_die "unknown report verb '${1:-}' (see 'apigee report --help')" ;;
  esac
}
