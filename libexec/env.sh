# shellcheck shell=bash
#
# Organization / environment level resources:
#   apigee org get
#   apigee env list|get|health|export
#   apigee cache list|clear            (Edge only)
#   apigee virtualhost list|get        (Edge only)
#   apigee envgroup list|get           (X/hybrid only)
#   apigee user list                   (Edge only)

org_verbs() { printf '%s\n' get; }
env_verbs() { printf '%s\n' list get health export import; }
cache_verbs() { printf '%s\n' list clear; }
virtualhost_verbs() { printf '%s\n' list get; }
envgroup_verbs() { printf '%s\n' list get; }
user_verbs() { printf '%s\n' list; }

org_help() {
  case "${1:-}" in
    "" | get) printf 'Usage: apigee org get\n\nPrint the organization (a read-only call; also used by setup/doctor.sh).\n' ;;
    *) apigee_die "unknown org verb '$1'" ;;
  esac
}

env_help() {
  case "${1:-}" in
    "")
      cat <<'EOF'
Usage: apigee env <verb>

Verbs:
  list               List environments
  get [ENV]          Show an environment (default --env)
  health [ENV]       Report deployments and their state; exit 1 if any failed
  export DIR         Snapshot --env: target servers, KVMs, keystores, deployed bundles,
                     plus the org's developers, API products and apps
  import DIR         Recreate a snapshot in --env (and the org-level data)
EOF
      ;;
    list) printf 'Usage: apigee env list\n\nList environment names.\n' ;;
    get) printf 'Usage: apigee env get [ENV]\n\nPrint the environment JSON.\n' ;;
    health)
      cat <<'EOF'
Usage: apigee env health [ENV]

Check that the environment exists and list "name revision state" for each
deployment. Exits 1 when any deployment reports an error/failed state.
EOF
      ;;
    export)
      cat <<'EOF'
Usage: apigee env export DIR [options]

Write a snapshot of --env into DIR:
  DIR/targetservers/NAME.json   DIR/kvms/MAP.json   DIR/keystores/NAME.json (metadata only)
  DIR/virtualhosts/NAME.json (Edge)   DIR/caches/NAME.json (Edge)
  DIR/envgroups/NAME.json (X/hybrid)
  DIR/proxies/NAME-revN.zip     DIR/sharedflows/NAME-revN.zip (deployed revisions)
Org-level data (not specific to --env):
  DIR/developers/EMAIL.json  DIR/products/NAME.json  DIR/apps/EMAIL/NAME.json

Options:
  --no-bundles --no-kvms --no-keystores --no-developers --no-products --no-apps
  --kvm-format json|lines
  --show-credentials   write app consumer keys and secrets (default: "<redacted>")

KVM files and exported credentials are secrets; keep DIR out of version control.
Private keys and certificates are not exported by Apigee.
EOF
      ;;
    import)
      cat <<'EOF'
Usage: apigee env import DIR [options]

Recreate an 'apigee env export' snapshot in --env (and the org): target servers,
KVMs, developers, API products, apps, then proxy and shared flow bundles.
Keystores, env groups, virtual hosts and caches are exported for reference only
and are not imported.

Options:
  --no-targetservers --no-kvms --no-developers --no-products --no-apps --no-bundles
  --deploy        deploy each imported bundle revision to --env (shared flows first)
  --overwrite     update things that already exist (default: skip them)
  --allow-masked  import KVM values that are all asterisks (see 'apigee kvm import --help')

Asks for confirmation once. Use -n/--dry-run to see the requests without sending them.
EOF
      ;;
    *) apigee_die "unknown env verb '$1' (see 'apigee env --help')" ;;
  esac
}

cache_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee cache <verb>   (Apigee Edge only)\n\nVerbs:\n  list          List caches in --env\n  clear NAME    Clear all entries of a cache\n' ;;
    list) printf 'Usage: apigee cache list\n\nList caches in --env (Apigee Edge only).\n' ;;
    clear) printf 'Usage: apigee cache clear NAME [--prefix PREFIX]\n\nClear cache entries (Apigee Edge only). Mutating: asks for confirmation.\n' ;;
    *) apigee_die "unknown cache verb '$1'" ;;
  esac
}

virtualhost_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee virtualhost <verb>   (Apigee Edge only)\n\nVerbs:\n  list         List virtual hosts in --env\n  get NAME     Show a virtual host\n\nOn Apigee X/hybrid use environment groups (apigee envgroup).\n' ;;
    list) printf 'Usage: apigee virtualhost list\n\nList virtual hosts in --env (Apigee Edge only).\n' ;;
    get) printf 'Usage: apigee virtualhost get NAME\n\nShow a virtual host (Apigee Edge only).\n' ;;
    *) apigee_die "unknown virtualhost verb '$1'" ;;
  esac
}

envgroup_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee envgroup <verb>   (Apigee X/hybrid only)\n\nVerbs:\n  list         List environment groups\n  get NAME     Show an environment group and its attachments\n\nOn Apigee Edge use virtual hosts (apigee virtualhost).\n' ;;
    list) printf 'Usage: apigee envgroup list\n\nList environment groups (Apigee X/hybrid only).\n' ;;
    get) printf 'Usage: apigee envgroup get NAME\n\nShow an environment group, then its environment attachments.\n' ;;
    *) apigee_die "unknown envgroup verb '$1'" ;;
  esac
}

user_help() {
  case "${1:-}" in
    "" | list) printf 'Usage: apigee user list   (Apigee Edge only)\n\nList organization users. On Apigee X/hybrid, users are Google Cloud IAM\nprincipals: use gcloud projects get-iam-policy.\n' ;;
    *) apigee_die "unknown user verb '$1'" ;;
  esac
}

org_main() {
  case "${1:-}" in
    get) apigee_get "$(apigee_org_path)" | apigee_json pretty ;;
    *) apigee_die "unknown org verb '${1:-}' (see 'apigee org --help')" ;;
  esac
}

env_health() {
  [[ -n "${1:-}" ]] && APIGEE_ENV="$1"
  local env body lines bad
  env="$(apigee_env)"
  apigee_get "$(apigee_env_path)" >/dev/null || apigee_die "environment '$env' not reachable"
  body="$(apigee_get "$(apigee_env_path)/deployments")" || exit 1
  lines="$(printf '%s' "$body" | apigee_json env-deployments)"
  printf 'environment %s: %s deployment(s)\n' "$env" "$(printf '%s' "$lines" | grep -c . || true)"
  if [[ -n "$lines" ]]; then
    printf '%s\n' "$lines" | awk '{printf "  %-40s rev %-5s %s\n", $1, $2, $3}'
  fi
  bad="$(printf '%s\n' "$lines" | awk 'tolower($3) ~ /error|fail/' || true)"
  if [[ -n "$bad" ]]; then
    apigee_warn "unhealthy deployments found"
    return 1
  fi
}

env_export() {
  local dir="" bundles=true kvms=true kvm_format=json keystores=true developers=true products=true apps=true creds=""
  while (($#)); do
    case "$1" in
      --no-bundles) bundles=false; shift ;;
      --no-kvms) kvms=false; shift ;;
      --no-keystores) keystores=false; shift ;;
      --no-developers) developers=false; shift ;;
      --no-products) products=false; shift ;;
      --no-apps) apps=false; shift ;;
      --show-credentials) creds=--show-credentials; shift ;;
      --kvm-format) kvm_format="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [[ -n "$dir" ]] || apigee_die "missing DIR"
  (umask 077 && mkdir -p "$dir/targetservers")
  local ts
  for ts in $(targetserver_main list); do
    apigee_get "$(targetserver_path "$ts")" | apigee_json pretty | export_write "$dir/targetservers/$ts.json"
  done
  apigee_info "exported target servers to $dir/targetservers"
  if [[ "$APIGEE_KIND" == edge ]]; then
    (umask 077 && mkdir -p "$dir/virtualhosts")
    local vh
    for vh in $(virtualhost_main list); do
      apigee_get "$(apigee_env_path)/virtualhosts/$(apigee_urlencode "$vh")" | apigee_json pretty | export_write "$dir/virtualhosts/$vh.json"
    done
    apigee_info "exported virtual hosts to $dir/virtualhosts"
  fi
  if [[ "$kvms" == true ]]; then
    kvm_main export --out "$dir/kvms" --format "$kvm_format"
  fi
  if [[ "$keystores" == true ]]; then
    local ks
    (umask 077 && mkdir -p "$dir/keystores")
    for ks in $(keystore_main list); do
      keystore_main get "$ks" | export_write "$dir/keystores/$ks.json"
    done
    apigee_info "exported keystore metadata to $dir/keystores"
  fi
  if [[ "$APIGEE_KIND" == edge ]]; then
    local c
    (umask 077 && mkdir -p "$dir/caches")
    for c in $(cache_main list); do
      apigee_get "$(apigee_env_path)/caches/$(apigee_urlencode "$c")" | apigee_json pretty | export_write "$dir/caches/$c.json"
    done
    apigee_info "exported caches to $dir/caches"
  else
    local g
    (umask 077 && mkdir -p "$dir/envgroups")
    for g in $(envgroup_main list); do
      apigee_get "$(apigee_org_path)/envgroups/$(apigee_urlencode "$g")" | apigee_json pretty | export_write "$dir/envgroups/$g.json"
    done
    apigee_info "exported env groups to $dir/envgroups"
  fi
  [[ "$developers" == true ]] && developer_export "$dir"
  [[ "$products" == true ]] && product_export "$dir"
  if [[ "$apps" == true ]]; then
    app_export "$dir" $creds
  fi
  if [[ "$bundles" == true ]]; then
    local label sub name rev
    for label in proxy sharedflow; do
      if [[ "$label" == proxy ]]; then sub=proxies; else sub=sharedflows; fi
      (umask 077 && mkdir -p "$dir/$sub")
      for name in $(bundle_list "$label"); do
        rev="$(bundle_deployed_env "$label" "$name" | tail -n 1)"
        [[ -n "$rev" ]] || continue
        bundle_download_to "$label" "$name" "$rev" "$dir/$sub/$name-rev$rev.zip"
      done
      apigee_info "exported deployed ${sub} to $dir/$sub"
    done
  fi
}

env_import_bundles() {
  local label="$1" sub="$2" dir="$3" deploy="$4" results="$5" zip base name rev
  [[ -d "$dir/$sub" ]] || return 0
  for zip in "$dir/$sub"/*.zip; do
    [[ -f "$zip" ]] || continue
    base="$(basename "$zip" .zip)"
    name="${base%-rev*}"
    if rev="$(bundle_import "$label" "$name" "$zip")" && [[ -n "$rev" ]]; then
      apigee_info "imported $label $name as revision $rev"
      if [[ "$deploy" == true ]]; then
        if bundle_deploy "$label" "$name" "$rev" >/dev/null; then
          echo created >>"$results"
        else
          apigee_warn "deploy of $label $name revision $rev failed"
          echo failed >>"$results"
        fi
      else
        echo created >>"$results"
      fi
    else
      apigee_warn "import of $label $name from $zip failed"
      echo failed >>"$results"
    fi
  done
}

env_import() {
  local dir="" ts=true kvms=true developers=true products=true apps=true bundles=true deploy=false overwrite=false masked="" res
  bundles=true
  while (($#)); do
    case "$1" in
      --no-targetservers) ts=false; shift ;;
      --no-kvms) kvms=false; shift ;;
      --no-developers) developers=false; shift ;;
      --no-products) products=false; shift ;;
      --no-apps) apps=false; shift ;;
      --no-bundles) bundles=false; shift ;;
      --deploy) deploy=true; shift ;;
      --overwrite) overwrite=true; shift ;;
      --allow-masked) masked=--allow-masked; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [[ -n "$dir" ]] || apigee_die "missing DIR"
  [[ -d "$dir" ]] || apigee_die "no such directory: $dir"
  local ow=""
  [[ "$overwrite" == true ]] && ow=--overwrite

  local plan=""
  count_of() { find "$dir/$1" -mindepth 1 -maxdepth "${3:-1}" -type f -name "$2" 2>/dev/null | wc -l | tr -d ' '; }
  [[ "$ts" == true && -d "$dir/targetservers" ]] && plan="$plan  $(count_of targetservers '*.json') target server(s)
"
  [[ "$kvms" == true && -d "$dir/kvms" ]] && plan="$plan  $(count_of kvms '*.json') key value map(s) (.json)
"
  [[ "$developers" == true && -d "$dir/developers" ]] && plan="$plan  $(count_of developers '*.json') developer(s)
"
  [[ "$products" == true && -d "$dir/products" ]] && plan="$plan  $(count_of products '*.json') API product(s)
"
  [[ "$apps" == true && -d "$dir/apps" ]] && plan="$plan  $(count_of apps '*.json' 2) app(s)
"
  if [[ "$bundles" == true ]]; then
    [[ -d "$dir/sharedflows" ]] && plan="$plan  $(count_of sharedflows '*.zip') shared flow bundle(s)
"
    [[ -d "$dir/proxies" ]] && plan="$plan  $(count_of proxies '*.zip') proxy bundle(s)
"
  fi
  [[ -n "$plan" ]] || apigee_die "nothing to import in $dir (expected targetservers/, kvms/, developers/, products/, apps/, proxies/, sharedflows/)"
  printf 'Importing from %s:\n%s' "$dir" "$plan" >&2
  apigee_confirm "Import the items listed above into org '$(apigee_org)', environment '$(apigee_env)' (deploy=$deploy, overwrite=$overwrite)."

  # One confirmation covers every step below.
  local APIGEE_YES=1 failed=0 results f name
  results="$(apigee_mktemp results)"

  if [[ "$ts" == true && -d "$dir/targetservers" ]]; then
    : >"$results"
    for f in "$dir"/targetservers/*.json; do
      [[ -f "$f" ]] || continue
      name="$(apigee_json get name <"$f")"
      if res="$(import_one "$(targetserver_path)" "$(targetserver_path "$name")" "$(apigee_json omit <"$f")" "$overwrite")"; then
        echo "$res" >>"$results"
      else
        echo failed >>"$results"
      fi
    done
    import_report "target servers" "$results" || failed=1
  fi
  if [[ "$kvms" == true && -d "$dir/kvms" ]]; then
    kvm_main import "$dir/kvms" $masked || failed=1
  fi
  if [[ "$developers" == true && -d "$dir/developers" ]]; then
    developer_import "$dir" $ow || failed=1
  fi
  if [[ "$products" == true && -d "$dir/products" ]]; then
    product_import "$dir" $ow || failed=1
  fi
  if [[ "$apps" == true && -d "$dir/apps" ]]; then
    app_import "$dir" $ow || failed=1
  fi
  if [[ "$bundles" == true ]]; then
    : >"$results"
    env_import_bundles sharedflow sharedflows "$dir" "$deploy" "$results"
    env_import_bundles proxy proxies "$dir" "$deploy" "$results"
    if [[ -s "$results" ]]; then import_report "bundles" "$results" || failed=1; fi
  fi
  return "$failed"
}

env_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    list)
      local body
      body="$(apigee_get "$(apigee_org_path)/environments")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      # shellcheck disable=SC2034
      [[ -n "${1:-}" ]] && APIGEE_ENV="$1"
      apigee_get "$(apigee_env_path)" | apigee_json pretty
      ;;
    health) env_health "$@" ;;
    export) env_export "$@" ;;
    import) env_import "$@" ;;
    *) apigee_die "unknown env verb '$verb' (see 'apigee env --help')" ;;
  esac
}

cache_main() {
  apigee_require_platform edge "apigee cache"
  local verb="${1:-}"
  shift || true
  case "$verb" in
    list)
      local body
      body="$(apigee_get "$(apigee_env_path)/caches")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    clear)
      local name="" prefix=""
      while (($#)); do
        case "$1" in
          --prefix) prefix="$2"; shift 2 ;;
          -*) apigee_die "unknown option $1" ;;
          *) name="$1"; shift ;;
        esac
      done
      [[ -n "$name" ]] || apigee_die "missing NAME"
      local q="action=clear"
      [[ -n "$prefix" ]] && q="$q&prefix=$(apigee_urlencode "$prefix")"
      apigee_confirm "Clear cache '$name'${prefix:+ (prefix $prefix)} in '$(apigee_env)'."
      apigee_request POST "$(apigee_env_path)/caches/$(apigee_urlencode "$name")/entries?$q" \
        --content-type application/octet-stream >/dev/null
      ;;
    *) apigee_die "unknown cache verb '$verb' (see 'apigee cache --help')" ;;
  esac
}

virtualhost_main() {
  apigee_require_platform edge "apigee virtualhost (use 'apigee envgroup' on X/hybrid)"
  case "${1:-}" in
    list)
      local body
      body="$(apigee_get "$(apigee_env_path)/virtualhosts")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      [[ -n "${2:-}" ]] || apigee_die "missing NAME"
      apigee_get "$(apigee_env_path)/virtualhosts/$(apigee_urlencode "$2")" | apigee_json pretty
      ;;
    *) apigee_die "unknown virtualhost verb '${1:-}' (see 'apigee virtualhost --help')" ;;
  esac
}

envgroup_main() {
  apigee_require_platform x "apigee envgroup (use 'apigee virtualhost' on Edge)"
  case "${1:-}" in
    list)
      local body
      body="$(apigee_get "$(apigee_org_path)/envgroups")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      [[ -n "${2:-}" ]] || apigee_die "missing NAME"
      local path
      path="$(apigee_org_path)/envgroups/$(apigee_urlencode "$2")"
      apigee_get "$path" | apigee_json pretty
      apigee_get "$path/attachments" | apigee_json pretty
      ;;
    *) apigee_die "unknown envgroup verb '${1:-}' (see 'apigee envgroup --help')" ;;
  esac
}

user_main() {
  apigee_require_platform edge "apigee user (X/hybrid users are Cloud IAM principals)"
  case "${1:-}" in
    list)
      local body
      body="$(apigee_get "$(apigee_org_path)/users")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    *) apigee_die "unknown user verb '${1:-}' (see 'apigee user --help')" ;;
  esac
}
