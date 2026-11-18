# shellcheck shell=bash
#
# apigee app|developer|product <verb> — developer apps, developers, API products.

app_verbs() { printf '%s\n' list get approve revoke export import; }
developer_verbs() { printf '%s\n' list get export import; }
product_verbs() { printf '%s\n' list get export import; }

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
  export [DIR]                         Write every app to DIR/apps/EMAIL/NAME.json
  import DIR                           Create apps from an export

Run 'apigee app <verb> --help' for details.
EOF
      ;;
    list) printf 'Usage: apigee app list [--expand]\n\nList app IDs; with --expand, list app names.\n' ;;
    get) printf 'Usage: apigee app get [--show-credentials] APP_ID\n       apigee app get [--show-credentials] --developer EMAIL APP_NAME\n\nPrint the app as JSON. Consumer keys and secrets are shown as "<redacted>"\nunless --show-credentials is given.\n' ;;
    export)
      cat <<'EOF'
Usage: apigee app export [DIR] [--show-credentials]

Write every developer app to DIR/apps/DEVELOPER_EMAIL/APP_NAME.json
(default DIR: ./export/ORG). Consumer keys and secrets are written as
"<redacted>" unless --show-credentials is given; with it the files are
secrets, so keep DIR out of version control (files are created mode 600).
EOF
      ;;
    import)
      cat <<'EOF'
Usage: apigee app import DIR [--overwrite]

Create the apps found in DIR/apps/EMAIL/NAME.json (or DIR itself). The developer
and the API products named in each file must already exist. Credentials that were
exported with --show-credentials are restored (the key Apigee generates on
creation is removed); redacted ones are not, so the app gets a new key.
Existing apps are skipped, or updated with --overwrite. Mutating: asks for confirmation.
EOF
      ;;
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
    "") printf 'Usage: apigee developer <verb>\n\nVerbs:\n  list          List developer emails\n  get EMAIL     Show a developer\n  export [DIR]  Write every developer to DIR/developers/EMAIL.json\n  import DIR    Create developers from an export (--overwrite to update)\n' ;;
    export) printf 'Usage: apigee developer export [DIR]\n\nWrite every developer to DIR/developers/EMAIL.json (default DIR: ./export/ORG).\n' ;;
    import) printf 'Usage: apigee developer import DIR [--overwrite]\n\nCreate developers from DIR/developers/*.json (or DIR). Existing developers are\nskipped, or updated with --overwrite. Mutating: asks for confirmation.\n' ;;
    list) printf 'Usage: apigee developer list\n\nList developer emails, one per line.\n' ;;
    get) printf 'Usage: apigee developer get EMAIL\n\nPrint the developer as JSON.\n' ;;
    *) apigee_die "unknown developer verb '$1' (see 'apigee developer --help')" ;;
  esac
}

product_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee product <verb>\n\nVerbs:\n  list          List API product names\n  get NAME      Show an API product\n  export [DIR]  Write every product to DIR/products/NAME.json\n  import DIR    Create products from an export (--overwrite to update)\n' ;;
    export) printf 'Usage: apigee product export [DIR]\n\nWrite every API product to DIR/products/NAME.json (default DIR: ./export/ORG).\n' ;;
    import) printf 'Usage: apigee product import DIR [--overwrite]\n\nCreate API products from DIR/products/*.json (or DIR). Existing products are\nskipped, or updated with --overwrite. Mutating: asks for confirmation.\n' ;;
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

# ---------------------------------------------------------------------------
# export / import of org-level data (developers, API products, apps)
# ---------------------------------------------------------------------------

# Write stdin to FILE with mode 600 (exports can hold PII and credentials).
export_write() {
  (umask 077 && cat >"$1")
}

export_default_dir() {
  printf './export/%s\n' "$(apigee_org)"
}

# DIR/SUB when it exists, otherwise DIR itself.
export_subdir() {
  if [[ -d "$1/$2" ]]; then printf '%s\n' "$1/$2"; else printf '%s\n' "$1"; fi
}

developer_export() {
  local dir="" d out body n=0
  while (($#)); do
    case "$1" in
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  dir="${dir:-$(export_default_dir)}"
  out="$dir/developers"
  (umask 077 && mkdir -p "$out")
  for d in $(developer_list); do
    body="$(apigee_get "$(apigee_org_path)/developers/$(apigee_urlencode "$d")")" || exit 1
    printf '%s' "$body" | apigee_json pretty | export_write "$out/$d.json"
    n=$((n + 1))
  done
  apigee_info "exported $n developers to $out"
}

product_export() {
  local dir="" p out body n=0
  while (($#)); do
    case "$1" in
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  dir="${dir:-$(export_default_dir)}"
  out="$dir/products"
  (umask 077 && mkdir -p "$out")
  for p in $(product_main list); do
    body="$(apigee_get "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$p")")" || exit 1
    printf '%s' "$body" | apigee_json pretty | export_write "$out/$p.json"
    n=$((n + 1))
  done
  apigee_info "exported $n API products to $out"
}

# Print an app document, hiding consumer keys/secrets unless asked.
app_emit() {
  if [[ "${APP_SHOW_CREDENTIALS:-false}" == true ]]; then
    apigee_json pretty
  else
    apigee_json redact-credentials
  fi
}

app_export() {
  local dir="" d out body line name n=0
  APP_SHOW_CREDENTIALS=false
  while (($#)); do
    case "$1" in
      --show-credentials) APP_SHOW_CREDENTIALS=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  dir="${dir:-$(export_default_dir)}"
  out="$dir/apps"
  if [[ "$APP_SHOW_CREDENTIALS" == true ]]; then
    apigee_warn "--show-credentials: consumer keys and secrets will be written to $out"
  fi
  for d in $(developer_list); do
    body="$(apigee_get "$(apigee_org_path)/developers/$(apigee_urlencode "$d")/apps?expand=true")" || exit 1
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      name="$(printf '%s' "$line" | apigee_json get name)"
      [[ -n "$name" ]] || continue
      (umask 077 && mkdir -p "$out/$d")
      printf '%s' "$line" | app_emit | export_write "$out/$d/$name.json"
      n=$((n + 1))
    done <<EOF
$(printf '%s' "$body" | apigee_json items app)
EOF
  done
  apigee_info "exported $n apps to $out"
}

# JSON files to import: DIR/SUB/... when DIR has a SUB folder, else DIR itself.
import_files() {
  local dir="$1" sub="$2" depth="$3"
  [[ -d "$dir" ]] || apigee_die "no such directory: $dir"
  find "$(export_subdir "$dir" "$sub")" -mindepth 1 -maxdepth "$depth" -type f -name '*.json' | sort
}

# POST BODY to PATH; on 409 PUT to UPDATE_PATH (overwrite) or skip.
# Prints "created", "updated" or "skipped".
import_one() {
  local path="$1" update_path="$2" body="$3" overwrite="$4" result
  apigee_request POST "$path" --json "$body" --ok 409 >/dev/null || return 1
  if [[ "$(apigee_last_status)" == 409 ]]; then
    if [[ "$overwrite" == true ]]; then
      apigee_request PUT "$update_path" --json "$body" >/dev/null || return 1
      result=updated
    else
      result=skipped
    fi
  else
    result=created
  fi
  printf '%s\n' "$result"
}

# Summarise a file of created/updated/skipped/failed lines; non-zero on failure.
import_report() {
  local what="$1" results="$2" created updated skipped failed
  created="$(grep -c '^created$' "$results" || true)"
  updated="$(grep -c '^updated$' "$results" || true)"
  skipped="$(grep -c '^skipped$' "$results" || true)"
  failed="$(grep -c '^failed$' "$results" || true)"
  apigee_info "$what: $created created, $updated updated, $skipped already existed (skipped), $failed failed"
  ((failed == 0))
}

developer_import() {
  local dir="" overwrite=false
  while (($#)); do
    case "$1" in
      --overwrite) overwrite=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [[ -n "$dir" ]] || apigee_die "missing DIR"
  local files f n body email res results
  files="$(import_files "$dir" developers 1)"
  n="$(printf '%s\n' "$files" | grep -c . || true)"
  ((n > 0)) || apigee_die "no developer files found in $dir"
  apigee_confirm "Import $n developer(s) from $dir into org '$(apigee_org)'."
  results="$(apigee_mktemp results)"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    email="$(apigee_json get email <"$f")"
    if [[ -z "$email" ]]; then
      apigee_warn "$f: no email; skipped"
      echo failed >>"$results"
      continue
    fi
    body="$(apigee_json omit developerId organizationName createdAt lastModifiedAt apps companies <"$f")"
    if res="$(import_one "$(apigee_org_path)/developers" "$(apigee_org_path)/developers/$(apigee_urlencode "$email")" "$body" "$overwrite")"; then
      echo "$res" >>"$results"
    else
      echo failed >>"$results"
    fi
  done <<EOF
$files
EOF
  import_report developers "$results"
}

product_import() {
  local dir="" overwrite=false
  while (($#)); do
    case "$1" in
      --overwrite) overwrite=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [[ -n "$dir" ]] || apigee_die "missing DIR"
  local files f n body name res results
  files="$(import_files "$dir" products 1)"
  n="$(printf '%s\n' "$files" | grep -c . || true)"
  ((n > 0)) || apigee_die "no API product files found in $dir"
  apigee_confirm "Import $n API product(s) from $dir into org '$(apigee_org)'."
  results="$(apigee_mktemp results)"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    name="$(apigee_json get name <"$f")"
    if [[ -z "$name" ]]; then
      apigee_warn "$f: no name; skipped"
      echo failed >>"$results"
      continue
    fi
    body="$(apigee_json omit createdAt lastModifiedAt <"$f")"
    if res="$(import_one "$(apigee_org_path)/apiproducts" "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$name")" "$body" "$overwrite")"; then
      echo "$res" >>"$results"
    else
      echo failed >>"$results"
    fi
  done <<EOF
$files
EOF
  import_report "API products" "$results"
}

# Restore exported credentials onto a freshly created app, then drop the key
# Apigee generated. $1 developer, $2 app, $3 export file, $4 created-app JSON.
app_restore_credentials() {
  local dev="$1" name="$2" file="$3" created="$4" cred key products generated base kpath
  base="$(app_dev_path "$dev" "$name")"
  generated="$(printf '%s' "$created" | apigee_json items credentials 2>/dev/null | head -n 1 | apigee_json get consumerKey 2>/dev/null || true)"
  while IFS= read -r cred; do
    [[ -n "$cred" ]] || continue
    key="$(printf '%s' "$cred" | apigee_json get consumerKey)"
    products="$(printf '%s' "$cred" | apigee_json get apiProducts)"
    if [[ "$APIGEE_KIND" == edge ]]; then kpath="$base/keys/create"; else kpath="$base/keys"; fi
    if ! apigee_request POST "$kpath" --json "$(printf '%s' "$cred" | apigee_json omit apiProducts)" >/dev/null; then
      apigee_warn "could not restore a credential of app $name"
      continue
    fi
    if [[ -n "$products" && "$products" != "[]" ]]; then
      apigee_request POST "$base/keys/$(apigee_urlencode "$key")" \
        --json "{\"apiProducts\":$products}" >/dev/null \
        || apigee_warn "could not attach API products to the restored key of app $name"
    fi
    if [[ -n "$generated" && "$generated" != "$key" ]]; then
      apigee_request DELETE "$base/keys/$(apigee_urlencode "$generated")" >/dev/null \
        || apigee_warn "could not remove the generated key of app $name"
      generated=""
    fi
  done <<EOF
$(apigee_json app-credentials <"$file")
EOF
}

app_import() {
  local dir="" overwrite=false
  while (($#)); do
    case "$1" in
      --overwrite) overwrite=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [[ -n "$dir" ]] || apigee_die "missing DIR"
  local files f n body name dev res results created
  files="$(import_files "$dir" apps 2)"
  n="$(printf '%s\n' "$files" | grep -c . || true)"
  ((n > 0)) || apigee_die "no app files found in $dir"
  apigee_confirm "Import $n app(s) from $dir into org '$(apigee_org)'."
  results="$(apigee_mktemp results)"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    name="$(apigee_json get name <"$f")"
    # the developer is the parent directory name (the export layout)
    dev="$(basename "$(dirname "$f")")"
    if [[ -z "$name" || "$dev" != *@* ]]; then
      apigee_warn "$f: cannot tell the developer (expected apps/EMAIL/NAME.json); skipped"
      echo failed >>"$results"
      continue
    fi
    body="$(apigee_json app-create-body <"$f")"
    if res="$(import_one "$(apigee_org_path)/developers/$(apigee_urlencode "$dev")/apps" "$(app_dev_path "$dev" "$name")" "$body" "$overwrite")"; then
      echo "$res" >>"$results"
      if [[ "$res" == created && "$APIGEE_DRY_RUN" != 1 ]]; then
        created="$(apigee_get "$(app_dev_path "$dev" "$name")")" || created="{}"
        app_restore_credentials "$dev" "$name" "$f" "$created"
      fi
    else
      echo failed >>"$results"
    fi
  done <<EOF
$files
EOF
  import_report apps "$results"
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
      APP_SHOW_CREDENTIALS=false
      local rest=() a app
      for a in "$@"; do
        if [[ "$a" == --show-credentials ]]; then APP_SHOW_CREDENTIALS=true; else rest+=("$a"); fi
      done
      app_parse_target ${rest[@]+"${rest[@]}"}
      [[ -n "$APP_NAME" ]] || apigee_die "missing APP_ID or APP_NAME"
      if [[ -n "$APP_DEV" ]]; then
        app="$(apigee_get "$(app_dev_path "$APP_DEV" "$APP_NAME")")" || exit 1
      else
        app="$(apigee_get "$(apigee_org_path)/apps/$(apigee_urlencode "$APP_NAME")")" || exit 1
      fi
      printf '%s' "$app" | app_emit
      ;;
    export) app_export "$@" ;;
    import) app_import "$@" ;;
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
    export) developer_export "$@" ;;
    import) developer_import "$@" ;;
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
    export) product_export "$@" ;;
    import) product_import "$@" ;;
    *) apigee_die "unknown product verb '$verb' (see 'apigee product --help')" ;;
  esac
}
