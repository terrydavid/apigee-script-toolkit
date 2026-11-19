# shellcheck shell=bash
#
# Apigee X / hybrid administration commands that the legacy toolkit never had but
# apigeecli offers: application groups, data collectors, data stores, references,
# security profiles, portal sites, API docs/categories, PSC endpoint attachments,
# operations, flow hooks, debug (trace) sessions, IAM policies, sync identities.
# One table-driven implementation serves the plain collections.

XAPI_RESOURCES="appgroup datacollector datastore reference securityprofile site endpoint operation apicategory apidoc"

xapi_def() { # RESOURCE -> XD_SCOPE XD_PATH XD_KEY XD_UPDATE XD_RO XD_NEEDS_SITE
  XD_SCOPE=org XD_KEY="" XD_UPDATE=PATCH XD_RO="" XD_NEEDS_SITE=""
  case "$1" in
    appgroup) XD_PATH=/appgroups XD_KEY=appGroups ;;
    datacollector) XD_PATH=/datacollectors XD_KEY=dataCollectors ;;
    datastore) XD_PATH=/analytics/datastores XD_UPDATE=PUT ;;
    reference) XD_SCOPE=env XD_PATH=/references XD_UPDATE=PUT ;;
    securityprofile) XD_PATH=/securityProfiles XD_KEY=securityProfiles ;;
    site) XD_PATH=/sites ;;
    endpoint) XD_PATH=/endpointAttachments XD_KEY=endpointAttachments ;;
    operation) XD_PATH=/operations XD_KEY=operations XD_RO=1 ;;
    apicategory) XD_PATH=/apicategories XD_NEEDS_SITE=1 ;;
    apidoc) XD_PATH=/apidocs XD_NEEDS_SITE=1 ;;
    *) return 1 ;;
  esac
}

for _r in $XAPI_RESOURCES; do
  eval "${_r}_verbs() { xapi_verbs $_r; }
${_r}_help() { xapi_help $_r \"\${1:-}\"; }
${_r}_main() { xapi_main $_r \"\$@\"; }"
done
unset _r

xapi_noun() {
  case "$1" in
    appgroup) printf 'application group' ;;
    datacollector) printf 'data collector' ;;
    datastore) printf 'analytics data store' ;;
    reference) printf 'environment reference' ;;
    securityprofile) printf 'advanced API security profile' ;;
    site) printf 'portal site' ;;
    endpoint) printf 'PSC endpoint attachment' ;;
    operation) printf 'long-running operation' ;;
    apicategory) printf 'API category (needs --site)' ;;
    apidoc) printf 'API catalog item (needs --site)' ;;
  esac
}

xapi_verbs() {
  xapi_def "$1"
  if [[ -n "$XD_RO" ]]; then printf '%s\n' list get; else printf '%s\n' list get create update delete; fi
}

xapi_help() {
  local r="$1" verb="${2:-}"
  xapi_def "$r"
  case "$verb" in
    "")
      printf 'Usage: apigee %s <verb> [options]   (Apigee X / hybrid only)\n\nManages %ss.\n\nVerbs:\n  list\n  get NAME\n' "$r" "$(xapi_noun "$r")"
      [[ -n "$XD_RO" ]] || printf '  create NAME [--description T] [--display-name T] [--type T] [--refers R --resource-type T] | --json BODY | --from-file F\n  update NAME --json BODY | --from-file F\n  delete NAME\n'
      [[ -z "$XD_NEEDS_SITE" ]] || printf '\n--site SITE selects the portal (required).\n'
      printf '\nMutating verbs ask for confirmation unless --yes.\n'
      ;;
    list | get | create | update | delete) printf 'Usage: apigee %s %s [NAME] [options]\n\nSee "apigee %s --help". Apigee X / hybrid only; mutating verbs ask for confirmation.\n' "$r" "$verb" "$r" ;;
    *) apigee_die "unknown $r verb '$verb'" ;;
  esac
}

xapi_main() {
  local r="$1" verb="${2:-}"
  shift 2 || true
  xapi_def "$r"
  case "$verb" in
    "" | -h | --help | help) xapi_help "$r" ""; return 0 ;;
  esac
  apigee_require_platform x "apigee $r"
  local name="" site="" desc="" disp="" typ="" refers="" rtype="" json="" from=""
  while (($#)); do
    case "$1" in
      --site) site="${2:?--site needs a value}"; shift 2 ;;
      --description) desc="${2:?}"; shift 2 ;;
      --display-name) disp="${2:?}"; shift 2 ;;
      --type) typ="${2:?}"; shift 2 ;;
      --refers) refers="${2:?}"; shift 2 ;;
      --resource-type) rtype="${2:?}"; shift 2 ;;
      --json) json="${2:?}"; shift 2 ;;
      --from-file) from="${2:?}"; shift 2 ;;
      -*) apigee_die "unknown option $1 (see 'apigee $r --help')" ;;
      *) name="$1"; shift ;;
    esac
  done
  local base
  if [[ "$XD_SCOPE" == env ]]; then base="$(apigee_env_path)"; else base="$(apigee_org_path)"; fi
  if [[ -n "$XD_NEEDS_SITE" ]]; then
    [[ -n "$site" ]] || apigee_die "$r needs --site SITE"
    base="$base/sites/$(apigee_urlencode "$site")"
  fi
  local coll="$base$XD_PATH"
  case "$verb" in
    list)
      if [[ -n "$XD_KEY" ]]; then apigee_get "$coll" | apigee_json names "$XD_KEY" | sort; else apigee_get "$coll" | apigee_json pretty; fi
      ;;
    get)
      [[ -n "$name" ]] || apigee_die "missing NAME"
      apigee_get "$coll/$(apigee_urlencode "$name")" | apigee_json pretty
      ;;
    create | update | delete)
      [[ -z "$XD_RO" ]] || apigee_die "$r is read-only"
      local body
      case "$verb" in
        create)
          if [[ -n "$from" ]]; then
            [[ -f "$from" ]] || apigee_die "no such file: $from"
            body="$(apigee_json omit <"$from")" || exit 1
            [[ -n "$name" ]] || name="$(printf '%s' "$body" | apigee_json get name)"
          elif [[ -n "$json" ]]; then
            body="$json"
          else
            [[ -n "$name" ]] || apigee_die "missing NAME"
            body="{\"name\":\"$(admin_esc "$name")\""
            [[ -z "$disp" ]] || body="$body,\"displayName\":\"$(admin_esc "$disp")\""
            [[ -z "$desc" ]] || body="$body,\"description\":\"$(admin_esc "$desc")\""
            [[ -z "$typ" ]] || body="$body,\"type\":\"$(admin_esc "$typ")\""
            [[ -z "$refers" ]] || body="$body,\"refers\":\"$(admin_esc "$refers")\""
            [[ -z "$rtype" ]] || body="$body,\"resourceType\":\"$(admin_esc "$rtype")\""
            body="$body}"
          fi
          apigee_confirm "Create $(xapi_noun "$r") '$name' in org '$(apigee_org)'."
          apigee_request POST "$coll" --json "$body" | apigee_json pretty
          ;;
        update)
          [[ -n "$name" ]] || apigee_die "missing NAME"
          if [[ -n "$from" ]]; then
            [[ -f "$from" ]] || apigee_die "no such file: $from"
            body="$(apigee_json omit <"$from")" || exit 1
          else
            [[ -n "$json" ]] || apigee_die "update needs --json BODY or --from-file FILE"
            body="$json"
          fi
          apigee_confirm "Update $(xapi_noun "$r") '$name' in org '$(apigee_org)'."
          apigee_request "$XD_UPDATE" "$coll/$(apigee_urlencode "$name")" --json "$body" | apigee_json pretty
          ;;
        delete)
          [[ -n "$name" ]] || apigee_die "missing NAME"
          apigee_confirm "Delete $(xapi_noun "$r") '$name' in org '$(apigee_org)'."
          apigee_request DELETE "$coll/$(apigee_urlencode "$name")" >/dev/null
          apigee_info "deleted $r $name"
          ;;
      esac
      ;;
    *) apigee_die "unknown $r verb '$verb' (see 'apigee $r --help')" ;;
  esac
}

# --- flow hooks ---------------------------------------------------------------------------

flowhook_verbs() { printf '%s\n' list get attach detach; }
flowhook_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee flowhook <verb>   (Apigee X / hybrid only; uses --env)\n\nVerbs:\n  list\n  get POINT\n  attach POINT --sharedflow NAME [--continue-on-error] [--description T]\n  detach POINT\n\nPOINT is PreProxyFlowHook, PreTargetFlowHook, PostTargetFlowHook or PostProxyFlowHook.\nattach/detach are mutating and ask for confirmation.\n' ;;
    list | get | attach | detach) flowhook_help "" ;;
    *) apigee_die "unknown flowhook verb '$1'" ;;
  esac
}

flowhook_main() {
  local verb="${1:-}" point="${2:-}"
  case "$verb" in
    "" | -h | --help | help) flowhook_help ""; return 0 ;;
  esac
  apigee_require_platform x "apigee flowhook"
  shift
  if (($#)) && [[ "$1" != -* ]]; then shift; fi
  local base sf="" coe=false desc=""
  base="$(apigee_env_path)/flowhooks"
  while (($#)); do
    case "$1" in
      --sharedflow) sf="${2:?}"; shift 2 ;;
      --continue-on-error) coe=true; shift ;;
      --description) desc="${2:?}"; shift 2 ;;
      *) apigee_die "unknown option $1" ;;
    esac
  done
  case "$verb" in
    list) apigee_get "$base" | apigee_json pretty ;;
    get | attach | detach)
      case "$point" in
        PreProxyFlowHook | PreTargetFlowHook | PostTargetFlowHook | PostProxyFlowHook) ;;
        *) apigee_die "POINT must be PreProxyFlowHook, PreTargetFlowHook, PostTargetFlowHook or PostProxyFlowHook" ;;
      esac
      case "$verb" in
        get) apigee_get "$base/$point" | apigee_json pretty ;;
        attach)
          [[ -n "$sf" ]] || apigee_die "missing --sharedflow NAME"
          apigee_confirm "Attach shared flow '$sf' to $point in '$(apigee_env)'."
          apigee_request PUT "$base/$point" --json "{\"sharedFlow\":\"$(admin_esc "$sf")\",\"continueOnError\":$coe${desc:+,\"description\":\"$(admin_esc "$desc")\"}}" | apigee_json pretty
          ;;
        detach)
          apigee_confirm "Detach whatever is attached to $point in '$(apigee_env)'."
          apigee_request DELETE "$base/$point" >/dev/null
          apigee_info "detached $point"
          ;;
      esac
      ;;
    *) apigee_die "unknown flowhook verb '$verb' (see 'apigee flowhook --help')" ;;
  esac
}

# --- debug (trace) sessions ---------------------------------------------------------------

trace_verbs() { printf '%s\n' create list get data delete; }
trace_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee trace <verb> PROXY REV [SESSION]   (Apigee X / hybrid only; uses --env)\n\nVerbs:\n  create PROXY REV [--session ID] [--timeout SEC] [--filter NAME=VALUE]...\n  list PROXY REV\n  get PROXY REV SESSION\n  data PROXY REV SESSION     Captured transactions of a session\n  delete PROXY REV SESSION\n\ncreate/delete are mutating and ask for confirmation.\n' ;;
    create | list | get | data | delete) trace_help "" ;;
    *) apigee_die "unknown trace verb '$1'" ;;
  esac
}

trace_main() {
  local verb="${1:-}"
  case "$verb" in
    "" | -h | --help | help) trace_help ""; return 0 ;;
  esac
  apigee_require_platform x "apigee trace"
  shift
  local pos=() session="" timeout="" filters="" base
  while (($#)); do
    case "$1" in
      --session) session="${2:?}"; shift 2 ;;
      --timeout) timeout="${2:?}"; shift 2 ;;
      --filter) filters="$filters${filters:+,}${2:?}"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) pos+=("$1"); shift ;;
    esac
  done
  [[ -n "${pos[0]:-}" && -n "${pos[1]:-}" ]] || apigee_die "usage: apigee trace $verb PROXY REV [SESSION]"
  base="$(apigee_env_path)/apis/$(apigee_urlencode "${pos[0]}")/revisions/$(apigee_urlencode "${pos[1]}")/debugsessions"
  [[ -n "$session" ]] || session="${pos[2]:-}"
  case "$verb" in
    create)
      local q="" body="{}"
      [[ -z "$session" ]] || q="session=$(apigee_urlencode "$session")"
      [[ -z "$timeout" ]] || q="$q${q:+&}timeout=$(apigee_urlencode "$timeout")"
      [[ -z "$filters" ]] || body="{\"filter\":\"$(admin_esc "$filters")\"}"
      apigee_confirm "Start a debug session on ${pos[0]} revision ${pos[1]} in '$(apigee_env)'."
      apigee_request POST "$base${q:+?$q}" --json "$body" | apigee_json pretty
      ;;
    list) apigee_get "$base" | apigee_json pretty ;;
    get | data | delete)
      [[ -n "$session" ]] || apigee_die "missing SESSION"
      case "$verb" in
        get) apigee_get "$base/$(apigee_urlencode "$session")" | apigee_json pretty ;;
        data) apigee_get "$base/$(apigee_urlencode "$session")/data" | apigee_json pretty ;;
        delete)
          apigee_confirm "Delete debug session '$session' of ${pos[0]} revision ${pos[1]}."
          apigee_request DELETE "$base/$(apigee_urlencode "$session")" >/dev/null
          apigee_info "deleted debug session $session"
          ;;
      esac
      ;;
    *) apigee_die "unknown trace verb '$verb' (see 'apigee trace --help')" ;;
  esac
}

# --- IAM and sync identities ----------------------------------------------------------------

iam_verbs() { printf '%s\n' get set; }
iam_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee iam <verb> [--scope org|env]   (Apigee X / hybrid only)\n\nVerbs:\n  get                     Show the IAM policy of the org (default) or --env\n  set --from-file FILE    Replace the policy with FILE ({"policy": {...}}); mutating\n\nsetIamPolicy replaces the whole policy: run get first and edit its output.\n' ;;
    get | set) iam_help "" ;;
    *) apigee_die "unknown iam verb '$1'" ;;
  esac
}

iam_main() {
  local verb="${1:-}"
  case "$verb" in
    "" | -h | --help | help) iam_help ""; return 0 ;;
  esac
  apigee_require_platform x "apigee iam"
  shift
  local scope=org from="" res
  while (($#)); do
    case "$1" in
      --scope) scope="${2:?}"; shift 2 ;;
      --from-file) from="${2:?}"; shift 2 ;;
      *) apigee_die "unknown option $1" ;;
    esac
  done
  case "$scope" in
    org) res="$(apigee_org_path)" ;;
    env) res="$(apigee_env_path)" ;;
    *) apigee_die "--scope must be org or env" ;;
  esac
  case "$verb" in
    get) apigee_get "$res:getIamPolicy" | apigee_json pretty ;;
    set)
      [[ -n "$from" && -f "$from" ]] || apigee_die "set needs --from-file FILE"
      apigee_confirm "REPLACE the IAM policy of the $scope in org '$(apigee_org)' with $from."
      apigee_request POST "$res:setIamPolicy" --data-file "$from" | apigee_json pretty
      ;;
    *) apigee_die "unknown iam verb '$verb' (see 'apigee iam --help')" ;;
  esac
}

sync_verbs() { printf '%s\n' get add remove; }
sync_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee sync <verb>   (Apigee hybrid / X)\n\nVerbs:\n  get                  Identities allowed to sync from the control plane\n  add IDENTITY...      Allow identities (e.g. serviceAccount:NAME@PROJECT.iam.gserviceaccount.com)\n  remove IDENTITY...   Stop allowing identities\n\nadd/remove keep the other identities and send the etag; mutating, ask for confirmation.\n' ;;
    get | add | remove) sync_help "" ;;
    *) apigee_die "unknown sync verb '$1'" ;;
  esac
}

sync_main() {
  local verb="${1:-}"
  case "$verb" in
    "" | -h | --help | help) sync_help ""; return 0 ;;
  esac
  apigee_require_platform x "apigee sync"
  shift
  local doc cur etag new="" id keep
  doc="$(apigee_request POST "$(apigee_org_path):getSyncAuthorization" --json '{}' --read-only)" || exit 1
  case "$verb" in
    get) printf '%s' "$doc" | apigee_json pretty ;;
    add | remove)
      (($#)) || apigee_die "usage: apigee sync $verb IDENTITY..."
      cur="$(printf '%s' "$doc" | apigee_json values identities)"
      etag="$(printf '%s' "$doc" | apigee_json get etag)"
      while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        keep=1
        if [[ "$verb" == remove ]]; then
          for x in "$@"; do [[ "$x" == "$id" ]] && keep=""; done
        fi
        [[ -z "$keep" ]] || new="$new$id"$'\n'
      done <<EOF
$cur
EOF
      if [[ "$verb" == add ]]; then
        for id in "$@"; do printf '%s' "$new" | grep -Fx -- "$id" >/dev/null || new="$new$id"$'\n'; done
      fi
      local arr=() line
      while IFS= read -r line; do [[ -n "$line" ]] && arr+=("$line"); done <<EOF
$new
EOF
      apigee_confirm "$verb sync identities ($*) for org '$(apigee_org)'."
      apigee_request POST "$(apigee_org_path):setSyncAuthorization" --json "{\"identities\":$(edge_arr "${arr[@]+"${arr[@]}"}")${etag:+,\"etag\":\"$(admin_esc "$etag")\"}}" | apigee_json pretty
      ;;
    *) apigee_die "unknown sync verb '$verb' (see 'apigee sync --help')" ;;
  esac
}

# --- key aliases (keystore resource) --------------------------------------------------------------

keystore_alias() { # label verb NAME ARGS...
  local label="$1" verb="$2" name="${3:-}" alias="${4:-}" cn="" days=365 size=2048 alias_opt="" org="" country=""
  shift 3 || true
  [[ -n "$name" ]] || apigee_die "missing NAME"
  local base
  base="$(keystore_path "$name")/aliases"
  case "$verb" in
    aliases) apigee_get "$base" | apigee_json names | sort ;;
    alias-get | cert | csr | alias-delete)
      [[ -n "$alias" ]] || apigee_die "missing ALIAS"
      case "$verb" in
        alias-get) apigee_get "$base/$(apigee_urlencode "$alias")" | apigee_json pretty ;;
        cert) apigee_request GET "$base/$(apigee_urlencode "$alias")/certificate" --accept '*/*' ;;
        csr) apigee_request GET "$base/$(apigee_urlencode "$alias")/csr" --accept '*/*' ;;
        alias-delete)
          apigee_confirm "Delete alias '$alias' from $label '$name' in '$(apigee_env)'."
          apigee_request DELETE "$base/$(apigee_urlencode "$alias")" >/dev/null
          apigee_info "deleted alias $alias"
          ;;
      esac
      ;;
    self-signed)
      local a
      while (($#)); do
        case "$1" in
          --alias) alias_opt="${2:?}"; shift 2 ;;
          --common-name) cn="${2:?}"; shift 2 ;;
          --days) days="${2:?}"; shift 2 ;;
          --key-size) size="${2:?}"; shift 2 ;;
          --org-name) org="${2:?}"; shift 2 ;;
          --country) country="${2:?}"; shift 2 ;;
          *) shift ;;
        esac
      done
      a="${alias_opt:-$alias}"
      [[ -n "$a" && -n "$cn" ]] || apigee_die "usage: apigee $label self-signed NAME --alias A --common-name CN [--days N] [--key-size N]"
      apigee_confirm "Create self-signed certificate alias '$a' in $label '$name' in '$(apigee_env)'."
      apigee_request POST "$base?alias=$(apigee_urlencode "$a")&format=selfsignedcert" \
        --json "{\"alias\":\"$(admin_esc "$a")\",\"keySize\":\"$size\",\"sigAlg\":\"SHA256withRSA\",\"certValidityInDays\":\"$days\",\"subject\":{\"commonName\":\"$(admin_esc "$cn")\"${org:+,\"org\":\"$(admin_esc "$org")\"}${country:+,\"countryCode\":\"$(admin_esc "$country")\"}}}" | apigee_json pretty
      ;;
  esac
}

# --- environment debug mask ---------------------------------------------------------------------------

env_debugmask() {
  local verb="${1:-}" from=""
  shift || true
  while (($#)); do
    case "$1" in
      --from-file) from="${2:?}"; shift 2 ;;
      *) apigee_die "unknown option $1" ;;
    esac
  done
  case "$verb" in
    get) apigee_get "$(apigee_env_path)/debugmask" | apigee_json pretty ;;
    set)
      [[ -n "$from" && -f "$from" ]] || apigee_die "set needs --from-file FILE"
      apigee_confirm "Replace the debug mask of '$(apigee_env)' with $from."
      apigee_request PATCH "$(apigee_env_path)/debugmask" --data-file "$from" | apigee_json pretty
      ;;
    *) apigee_die "usage: apigee env debugmask get|set [--from-file FILE]" ;;
  esac
}

# --- bulk export of the latest revision of every bundle ---------------------------------------------

bundle_export() {
  local label="$1" dir="." n rev names
  shift
  while (($#)); do
    case "$1" in
      --dir) dir="${2:?}"; shift 2 ;;
      *) apigee_die "unknown option $1" ;;
    esac
  done
  (umask 077 && mkdir -p "$dir")
  names="$(bundle_list "$label")" || exit 1
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    rev="$(bundle_latest "$label" "$n")" || exit 1
    bundle_download_to "$label" "$n" "$rev" "$dir/$n-rev$rev.zip"
    apigee_info "exported $label $n revision $rev"
  done <<EOF
$names
EOF
}
