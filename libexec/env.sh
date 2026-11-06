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
env_verbs() { printf '%s\n' list get health export; }
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
  export DIR         Snapshot target servers, KVMs and deployed bundles of --env
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
Usage: apigee env export DIR [--no-bundles] [--no-kvms] [--kvm-format json|lines]

Write a snapshot of --env into DIR:
  DIR/targetservers/NAME.json   DIR/kvms/MAP.json   DIR/virtualhosts/NAME.json (Edge)
  DIR/proxies/NAME-revN.zip     DIR/sharedflows/NAME-revN.zip (deployed revisions)
KVM files may contain secrets; keep DIR out of version control.
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
  local dir="" bundles=true kvms=true kvm_format=json
  while (($#)); do
    case "$1" in
      --no-bundles) bundles=false; shift ;;
      --no-kvms) kvms=false; shift ;;
      --kvm-format) kvm_format="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  [[ -n "$dir" ]] || apigee_die "missing DIR"
  (umask 077 && mkdir -p "$dir/targetservers")
  local ts
  for ts in $(targetserver_main list); do
    apigee_get "$(targetserver_path "$ts")" | apigee_json pretty >"$dir/targetservers/$ts.json"
  done
  apigee_info "exported target servers to $dir/targetservers"
  if [[ "$APIGEE_KIND" == edge ]]; then
    mkdir -p "$dir/virtualhosts"
    local vh
    for vh in $(virtualhost_main list); do
      apigee_get "$(apigee_env_path)/virtualhosts/$(apigee_urlencode "$vh")" | apigee_json pretty >"$dir/virtualhosts/$vh.json"
    done
    apigee_info "exported virtual hosts to $dir/virtualhosts"
  fi
  if [[ "$kvms" == true ]]; then
    kvm_main export --out "$dir/kvms" --format "$kvm_format"
  fi
  if [[ "$bundles" == true ]]; then
    local label sub name rev
    for label in proxy sharedflow; do
      if [[ "$label" == proxy ]]; then sub=proxies; else sub=sharedflows; fi
      mkdir -p "$dir/$sub"
      for name in $(bundle_list "$label"); do
        rev="$(bundle_deployed_env "$label" "$name" | tail -n 1)"
        [[ -n "$rev" ]] || continue
        bundle_download_to "$label" "$name" "$rev" "$dir/$sub/$name-rev$rev.zip"
      done
      apigee_info "exported deployed ${sub} to $dir/$sub"
    done
  fi
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
