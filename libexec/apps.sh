# shellcheck shell=bash
#
# apigee app|developer|product <verb> — developer apps, developers, API products.

app_verbs() { printf '%s\n' list get approve revoke; }
developer_verbs() { printf '%s\n' list get; }
product_verbs() { printf '%s\n' list get; }

app_help() {
  case "${1:-}" in
    "")
      cat <<'EOF'
Usage: apigee app <verb> [options]

Verbs:
  list [--expand]                      List app IDs (or app names with --expand)
  get APP_ID | --developer EMAIL NAME  Show an app
  approve --developer EMAIL NAME       Approve an app (or --all-pending)
  revoke --developer EMAIL NAME        Revoke an app

Run 'apigee app <verb> --help' for details.
EOF
      ;;
    list) printf 'Usage: apigee app list [--expand]\n\nList app IDs; with --expand, list app names.\n' ;;
    get) printf 'Usage: apigee app get APP_ID\n       apigee app get --developer EMAIL APP_NAME\n\nPrint the app as JSON.\n' ;;
    approve)
      cat <<'EOF'
Usage: apigee app approve --developer EMAIL APP_NAME
       apigee app approve --all-pending

Approve one app, or every app in the org whose status is "pending"
(case-insensitive). Apps with any other status that is not "approved", such
as "revoked", are never re-approved: they are listed as skipped.
Mutating: asks for confirmation.
EOF
      ;;
    revoke) printf 'Usage: apigee app revoke --developer EMAIL APP_NAME\n\nRevoke an app. Mutating: asks for confirmation.\n' ;;
    *) apigee_die "unknown app verb '$1' (see 'apigee app --help')" ;;
  esac
}

developer_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee developer <verb>\n\nVerbs:\n  list         List developer emails\n  get EMAIL    Show a developer\n' ;;
    list) printf 'Usage: apigee developer list\n\nList developer emails, one per line.\n' ;;
    get) printf 'Usage: apigee developer get EMAIL\n\nPrint the developer as JSON.\n' ;;
    *) apigee_die "unknown developer verb '$1' (see 'apigee developer --help')" ;;
  esac
}

product_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee product <verb>\n\nVerbs:\n  list        List API product names\n  get NAME    Show an API product\n' ;;
    list) printf 'Usage: apigee product list\n\nList API product names, one per line.\n' ;;
    get) printf 'Usage: apigee product get NAME\n\nPrint the API product as JSON.\n' ;;
    *) apigee_die "unknown product verb '$1' (see 'apigee product --help')" ;;
  esac
}

app_dev_path() {
  printf '%s/developers/%s/apps/%s\n' "$(apigee_org_path)" "$(apigee_urlencode "$1")" "$(apigee_urlencode "$2")"
}

app_parse_target() {
  APP_DEV=""
  APP_NAME=""
  while (($#)); do
    case "$1" in
      --developer) APP_DEV="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) APP_NAME="$1"; shift ;;
    esac
  done
}

app_set_status() {
  local action="$1" dev="$2" name="$3"
  apigee_request POST "$(app_dev_path "$dev" "$name")?action=$action" \
    --content-type application/octet-stream >/dev/null || return 1
  [[ "$APIGEE_DRY_RUN" == 1 ]] || apigee_info "${action}d app $name ($dev)"
}

app_approve_all_pending() {
  local devs dev body statuses status name plan="" count=0
  devs="$(developer_list)" || exit 1
  for dev in $devs; do
    body="$(apigee_get "$(apigee_org_path)/developers/$(apigee_urlencode "$dev")/apps?expand=true")" || exit 1
    statuses="$(printf '%s' "$body" | apigee_json app-statuses)"
    while read -r status name; do
      case "$status" in
        "" | approved) ;;
        pending)
          plan="$plan$dev $name
"
          count=$((count + 1))
          ;;
        *) apigee_info "skipping app $name ($dev): status is '$status', not 'pending'" ;;
      esac
    done <<EOF
$statuses
EOF
  done
  if ((count == 0)); then
    apigee_info "no pending apps"
    return 0
  fi
  printf '%s' "$plan" >&2
  apigee_confirm "Approve the $count app(s) listed above."
  local failed=0
  while read -r dev name; do
    [[ -n "$dev" ]] || continue
    app_set_status approve "$dev" "$name" || failed=1
  done <<EOF
$plan
EOF
  return "$failed"
}

developer_list() {
  local body
  body="$(apigee_get "$(apigee_org_path)/developers")" || exit 1
  printf '%s' "$body" | apigee_json names | sort
}

app_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    list)
      local q="" body
      [[ "${1:-}" == --expand ]] && q="?expand=true"
      body="$(apigee_get "$(apigee_org_path)/apps$q")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      app_parse_target "$@"
      [[ -n "$APP_NAME" ]] || apigee_die "missing APP_ID or APP_NAME"
      if [[ -n "$APP_DEV" ]]; then
        apigee_get "$(app_dev_path "$APP_DEV" "$APP_NAME")" | apigee_json pretty
      else
        apigee_get "$(apigee_org_path)/apps/$(apigee_urlencode "$APP_NAME")" | apigee_json pretty
      fi
      ;;
    approve | revoke)
      local a
      for a in "$@"; do
        if [[ "$verb" == approve && "$a" == --all-pending ]]; then
          (($# == 1)) || apigee_die "--all-pending takes no other arguments"
          app_approve_all_pending
          return
        fi
      done
      app_parse_target "$@"
      [[ -n "$APP_DEV" && -n "$APP_NAME" ]] || apigee_die "usage: apigee app $verb --developer EMAIL APP_NAME"
      apigee_confirm "Set app '$APP_NAME' of developer '$APP_DEV' to '$verb'."
      app_set_status "$verb" "$APP_DEV" "$APP_NAME"
      ;;
    *) apigee_die "unknown app verb '$verb' (see 'apigee app --help')" ;;
  esac
}

developer_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    list) developer_list ;;
    get)
      [[ -n "${1:-}" ]] || apigee_die "missing EMAIL"
      apigee_get "$(apigee_org_path)/developers/$(apigee_urlencode "$1")" | apigee_json pretty
      ;;
    *) apigee_die "unknown developer verb '$verb' (see 'apigee developer --help')" ;;
  esac
}

product_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    list)
      local body
      body="$(apigee_get "$(apigee_org_path)/apiproducts")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      [[ -n "${1:-}" ]] || apigee_die "missing NAME"
      apigee_get "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$1")" | apigee_json pretty
      ;;
    *) apigee_die "unknown product verb '$verb' (see 'apigee product --help')" ;;
  esac
}
