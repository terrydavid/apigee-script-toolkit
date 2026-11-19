# shellcheck shell=bash
#
# Write verbs for developers, apps, credentials (consumer keys) and API products.
# Hooked into 'apigee developer|app|product' (apps.sh) and the 'credential' resource.
#
# Replaces the legacy createDeveloper, deleteDeveloper, createDeveloperfromFile.sh,
# createApp(s), createAppfromFile, loadApp, postApp, deleteApp, deleteAppsBulk,
# addCredential, updateCredential, setCredentialApiProduct, deleteCredential,
# deleteKeys, getCredential(s), getKey(s), createApiProduct, updateApiProduct,
# deleteApiProduct, attachProx2Product, getProxFmProd and findApiProducts.
# Consumer secrets are never accepted as arguments (the legacy scripts took them
# on the command line): use APIGEE_CONSUMER_SECRET or --secret-file.

credential_verbs() { printf '%s\n' list get add set-products delete delete-all; }

# JSON string escape for a value (quotes and backslashes)
prov_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# prov_arr a b c -> ["a","b","c"]
prov_arr() {
  local out="" v
  for v in "$@"; do out="$out${out:+,}\"$(prov_esc "$v")\""; done
  printf '[%s]' "$out"
}

prov_compact() { apigee_json omit; }

prov_help() { # resource verb -> 0 if handled
  case "$1 ${2:-}" in
    "developer create") printf 'Usage: apigee developer create EMAIL [--first NAME] [--last NAME] [--user NAME] [--attr K=V]...\n       apigee developer create --from-file FILE.json\n\nCreate a developer. Mutating: asks for confirmation.\n' ;;
    "developer delete") printf 'Usage: apigee developer delete EMAIL\n\nDelete a developer (their apps are deleted with them). Mutating: asks for confirmation.\n' ;;
    "app create") printf 'Usage: apigee app create --developer EMAIL NAME [--product P]... [--callback URL] [--attr K=V]...\n       apigee app create --developer EMAIL --from-file FILE.json\n\nCreate an app; Apigee generates its first consumer key. Mutating: asks for confirmation.\n' ;;
    "app delete") printf 'Usage: apigee app delete --developer EMAIL NAME\n       apigee app delete --developer EMAIL --prefix PREFIX     (every app whose name starts with PREFIX)\n\nDelete apps. Mutating: lists what will be deleted and asks for confirmation.\n' ;;
    "product create") printf 'Usage: apigee product create NAME [--proxy P]... [--environment E]... [--display-name TEXT] [--approval auto|manual]\n               [--scope S]... [--quota N --quota-interval N --quota-unit minute|hour|day|month] [--description TEXT]\n\nCreate an API product. Mutating: asks for confirmation.\n' ;;
    "product delete") printf 'Usage: apigee product delete NAME\n\nDelete an API product. Mutating: asks for confirmation.\n' ;;
    "product attach-proxy" | "product detach-proxy") printf 'Usage: apigee product %s NAME PROXY\n\nAdd/remove a proxy in the product'"'"'s proxy list. Mutating: asks for confirmation.\n' "$2" ;;
    "product proxies") printf 'Usage: apigee product proxies NAME\n\nList the proxies of an API product.\n' ;;
    "product find") printf 'Usage: apigee product find --proxy PROXY\n\nList the API products that include PROXY.\n' ;;
    "credential ") printf 'Usage: apigee credential <verb> --developer EMAIL APP ...\n\nVerbs:\n  list APP                      Consumer keys and status of an app (no secrets)\n  get APP KEY [--show-credentials]  One credential (secret redacted unless asked)\n  add APP --key K [--product P]...  Add a credential; the secret comes from APIGEE_CONSUMER_SECRET or --secret-file FILE\n  set-products APP KEY P...     Set the API products of a credential\n  delete APP KEY                Delete a credential\n  delete-all APP                Delete every credential of an app\n' ;;
    "credential "*) prov_help credential "" ;;
    *) return 1 ;;
  esac
}

prov_confirmed() { apigee_confirm "$1"; }

# --- developer ------------------------------------------------------------

developer_create() {
  local email="" first="" last="" user="" from="" attrs=() body a
  while (($#)); do
    case "$1" in
      --first) first="${2:?--first needs a value}"; shift 2 ;;
      --last) last="${2:?--last needs a value}"; shift 2 ;;
      --user) user="${2:?--user needs a value}"; shift 2 ;;
      --attr) attrs+=("${2:?--attr needs K=V}"); shift 2 ;;
      --from-file) from="${2:?--from-file needs a file}"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) email="$1"; shift ;;
    esac
  done
  if [[ -n "$from" ]]; then
    [[ -f "$from" ]] || apigee_die "no such file: $from"
    body="$(prov_compact <"$from")" || exit 1
    email="$(printf '%s' "$body" | apigee_json get email)"
  else
    [[ -n "$email" ]] || apigee_die "missing EMAIL"
    [[ -n "$first" ]] || first="${email%%@*}"
    [[ -n "$last" ]] || last="User"
    [[ -n "$user" ]] || user="${email%%@*}"
    local at=""
    for a in "${attrs[@]+"${attrs[@]}"}"; do
      at="$at${at:+,}{\"name\":\"$(prov_esc "${a%%=*}")\",\"value\":\"$(prov_esc "${a#*=}")\"}"
    done
    body="{\"email\":\"$(prov_esc "$email")\",\"firstName\":\"$(prov_esc "$first")\",\"lastName\":\"$(prov_esc "$last")\",\"userName\":\"$(prov_esc "$user")\"${at:+,\"attributes\":[$at]}}"
  fi
  prov_confirmed "Create developer '$email' in org '$(apigee_org)'."
  apigee_request POST "$(apigee_org_path)/developers" --json "$body" | apigee_json pretty
}

developer_delete() {
  [[ -n "${1:-}" ]] || apigee_die "missing EMAIL"
  prov_confirmed "Delete developer '$1' and all of their apps in org '$(apigee_org)'."
  apigee_request DELETE "$(apigee_org_path)/developers/$(apigee_urlencode "$1")" >/dev/null
  apigee_info "deleted developer $1"
}

# --- app ----------------------------------------------------------------

app_create() {
  local dev="" name="" from="" cb="" prods=() attrs=() body a at=""
  while (($#)); do
    case "$1" in
      --developer) dev="${2:?--developer needs EMAIL}"; shift 2 ;;
      --product) prods+=("${2:?--product needs a name}"); shift 2 ;;
      --callback) cb="${2:?--callback needs a URL}"; shift 2 ;;
      --attr) attrs+=("${2:?--attr needs K=V}"); shift 2 ;;
      --from-file) from="${2:?--from-file needs a file}"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [[ -n "$dev" ]] || apigee_die "missing --developer EMAIL"
  if [[ -n "$from" ]]; then
    [[ -f "$from" ]] || apigee_die "no such file: $from"
    body="$(prov_compact <"$from")" || exit 1
    name="$(printf '%s' "$body" | apigee_json get name)"
  else
    [[ -n "$name" ]] || apigee_die "missing app NAME"
    for a in "${attrs[@]+"${attrs[@]}"}"; do
      at="$at${at:+,}{\"name\":\"$(prov_esc "${a%%=*}")\",\"value\":\"$(prov_esc "${a#*=}")\"}"
    done
    body="{\"name\":\"$(prov_esc "$name")\",\"apiProducts\":$(prov_arr "${prods[@]+"${prods[@]}"}")${cb:+,\"callbackUrl\":\"$(prov_esc "$cb")\"}${at:+,\"attributes\":[$at]}}"
  fi
  prov_confirmed "Create app '$name' for developer '$dev' in org '$(apigee_org)'."
  apigee_request POST "$(apigee_org_path)/developers/$(apigee_urlencode "$dev")/apps" --json "$body" \
    | apigee_json redact-credentials | apigee_json pretty
}

app_delete() {
  local dev="" name="" prefix="" names n
  while (($#)); do
    case "$1" in
      --developer) dev="${2:?--developer needs EMAIL}"; shift 2 ;;
      --prefix) prefix="${2:?--prefix needs a value}"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [[ -n "$dev" ]] || apigee_die "missing --developer EMAIL"
  if [[ -n "$prefix" ]]; then
    names="$(apigee_get "$(apigee_org_path)/developers/$(apigee_urlencode "$dev")/apps" | apigee_json names | grep -F -- "" | awk -v p="$prefix" 'index($0,p)==1')"
    [[ -n "$names" ]] || { apigee_info "no apps of $dev start with '$prefix'"; return 0; }
  else
    [[ -n "$name" ]] || apigee_die "missing app NAME (or --prefix PREFIX)"
    names="$name"
  fi
  printf '%s\n' "$names" >&2
  prov_confirmed "Delete the app(s) listed above for developer '$dev' in org '$(apigee_org)'."
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    apigee_request DELETE "$(app_dev_path "$dev" "$n")" >/dev/null
    apigee_info "deleted app $n"
  done <<EOF
$names
EOF
}

# --- credential -------------------------------------------------------------

credential_parse() { # sets CRED_DEV, CRED_POS[]
  CRED_DEV=""
  CRED_POS=()
  CRED_KEY="" CRED_PRODS=() CRED_SECRET_FILE="" CRED_SHOW=""
  while (($#)); do
    case "$1" in
      --developer) CRED_DEV="${2:?--developer needs EMAIL}"; shift 2 ;;
      --key) CRED_KEY="${2:?--key needs a value}"; shift 2 ;;
      --product) CRED_PRODS+=("${2:?--product needs a name}"); shift 2 ;;
      --secret-file) CRED_SECRET_FILE="${2:?--secret-file needs a file}"; shift 2 ;;
      --show-credentials) CRED_SHOW=1; shift ;;
      -*) apigee_die "unknown option $1 (see 'apigee credential --help')" ;;
      *) CRED_POS+=("$1"); shift ;;
    esac
  done
  [[ -n "$CRED_DEV" ]] || apigee_die "missing --developer EMAIL"
  [[ -n "${CRED_POS[0]:-}" ]] || apigee_die "missing APP"
}

credential_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    "" | -h | --help | help) prov_help credential ""; return 0 ;;
  esac
  credential_parse "$@"
  local app="${CRED_POS[0]}" base key secret doc
  base="$(app_dev_path "$CRED_DEV" "$app")"
  case "$verb" in
    list)
      apigee_get "$base" | apigee_json credential-keys
      ;;
    get)
      key="${CRED_POS[1]:-}"
      [[ -n "$key" ]] || apigee_die "missing KEY"
      doc="$(apigee_get "$base/keys/$(apigee_urlencode "$key")")" || exit 1
      if [[ -n "$CRED_SHOW" ]]; then printf '%s' "$doc" | apigee_json pretty; else printf '%s' "$doc" | apigee_json omit consumerSecret | apigee_json pretty; fi
      ;;
    add)
      [[ -n "$CRED_KEY" ]] || apigee_die "missing --key"
      if [[ -n "$CRED_SECRET_FILE" ]]; then secret="$(cat "$CRED_SECRET_FILE")"; else secret="${APIGEE_CONSUMER_SECRET:-}"; fi
      [[ -n "$secret" ]] || apigee_die "no secret: set APIGEE_CONSUMER_SECRET or pass --secret-file FILE (secrets are never taken as arguments)"
      prov_confirmed "Add credential '$CRED_KEY' to app '$app' of '$CRED_DEV' in org '$(apigee_org)'."
      apigee_request POST "$base/keys/create" \
        --json "{\"consumerKey\":\"$(prov_esc "$CRED_KEY")\",\"consumerSecret\":\"$(prov_esc "$secret")\"}" | apigee_json omit consumerSecret >/dev/null
      if ((${#CRED_PRODS[@]})); then
        apigee_request POST "$base/keys/$(apigee_urlencode "$CRED_KEY")" --json "{\"apiProducts\":$(prov_arr "${CRED_PRODS[@]}")}" >/dev/null
      fi
      apigee_info "added credential $CRED_KEY to $app"
      ;;
    set-products)
      key="${CRED_POS[1]:-}"
      [[ -n "$key" ]] || apigee_die "missing KEY"
      prov_confirmed "Set the API products of credential '$key' (app '$app') in org '$(apigee_org)'."
      apigee_request POST "$base/keys/$(apigee_urlencode "$key")" --json "{\"apiProducts\":$(prov_arr "${CRED_POS[@]:2}")}" >/dev/null
      apigee_info "set products of $key"
      ;;
    delete)
      key="${CRED_POS[1]:-}"
      [[ -n "$key" ]] || apigee_die "missing KEY"
      prov_confirmed "Delete credential '$key' of app '$app' ($CRED_DEV) in org '$(apigee_org)'."
      apigee_request DELETE "$base/keys/$(apigee_urlencode "$key")" >/dev/null
      apigee_info "deleted credential $key"
      ;;
    delete-all)
      local keys k
      keys="$(apigee_get "$base" | apigee_json credential-keys | awk '{print $1}')"
      [[ -n "$keys" ]] || { apigee_info "app $app has no credentials"; return 0; }
      printf '%s\n' "$keys" >&2
      prov_confirmed "Delete every credential listed above for app '$app' ($CRED_DEV) in org '$(apigee_org)'."
      while IFS= read -r k; do
        [[ -n "$k" ]] || continue
        apigee_request DELETE "$base/keys/$(apigee_urlencode "$k")" >/dev/null
        apigee_info "deleted credential $k"
      done <<EOF
$keys
EOF
      ;;
    *) apigee_die "unknown credential verb '$verb' (see 'apigee credential --help')" ;;
  esac
}

# --- product -----------------------------------------------------------------

product_create() {
  local name="" proxies=() envs=() scopes=() disp="" approval="" desc="" quota="" qint="" qunit="" body
  while (($#)); do
    case "$1" in
      --proxy) proxies+=("${2:?--proxy needs a name}"); shift 2 ;;
      --environment) envs+=("${2:?--environment needs a name}"); shift 2 ;;
      --scope) scopes+=("${2:?--scope needs a value}"); shift 2 ;;
      --display-name) disp="${2:?}"; shift 2 ;;
      --description) desc="${2:?}"; shift 2 ;;
      --approval) approval="${2:?}"; shift 2 ;;
      --quota) quota="${2:?}"; shift 2 ;;
      --quota-interval) qint="${2:?}"; shift 2 ;;
      --quota-unit) qunit="${2:?}"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [[ -n "$name" ]] || apigee_die "missing NAME"
  [[ -z "$approval" || "$approval" == auto || "$approval" == manual ]] || apigee_die "--approval must be auto or manual"
  body="{\"name\":\"$(prov_esc "$name")\",\"displayName\":\"$(prov_esc "${disp:-$name}")\",\"proxies\":$(prov_arr "${proxies[@]+"${proxies[@]}"}"),\"environments\":$(prov_arr "${envs[@]+"${envs[@]}"}")"
  [[ -z "$approval" ]] || body="$body,\"approvalType\":\"$approval\""
  [[ -z "$desc" ]] || body="$body,\"description\":\"$(prov_esc "$desc")\""
  ((${#scopes[@]} == 0)) || body="$body,\"scopes\":$(prov_arr "${scopes[@]}")"
  [[ -z "$quota" ]] || body="$body,\"quota\":\"$(prov_esc "$quota")\",\"quotaInterval\":\"${qint:-1}\",\"quotaTimeUnit\":\"${qunit:-minute}\""
  body="$body}"
  prov_confirmed "Create API product '$name' in org '$(apigee_org)'."
  apigee_request POST "$(apigee_org_path)/apiproducts" --json "$body" | apigee_json pretty
}

product_delete() {
  [[ -n "${1:-}" ]] || apigee_die "missing NAME"
  prov_confirmed "Delete API product '$1' in org '$(apigee_org)'."
  apigee_request DELETE "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$1")" >/dev/null
  apigee_info "deleted product $1"
}

product_proxies() {
  [[ -n "${1:-}" ]] || apigee_die "missing NAME"
  apigee_get "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$1")" | apigee_json values proxies
}

product_change_proxy() { # attach|detach NAME PROXY
  local mode="$1" name="${2:-}" proxy="${3:-}" doc cur new p
  [[ -n "$name" && -n "$proxy" ]] || apigee_die "usage: apigee product $mode-proxy NAME PROXY"
  doc="$(apigee_get "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$name")")" || exit 1
  cur="$(printf '%s' "$doc" | apigee_json values proxies)"
  new=()
  while IFS= read -r p; do
    [[ -n "$p" && "$p" != "$proxy" ]] && new+=("$p")
  done <<EOF
$cur
EOF
  [[ "$mode" == attach ]] && new+=("$proxy")
  prov_confirmed "$mode proxy '$proxy' ${mode/attach/to}${mode/detach/from} API product '$name' in org '$(apigee_org)'."
  printf '%s' "$doc" | apigee_json merge "{\"proxies\":$(prov_arr "${new[@]+"${new[@]}"}")}" | prov_compact \
    | apigee_request PUT "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$name")" --data-file /dev/stdin --content-type application/json >/dev/null
  apigee_info "$mode $proxy: product $name"
}

product_find() {
  local proxy="" n
  while (($#)); do
    case "$1" in
      --proxy) proxy="${2:?--proxy needs a name}"; shift 2 ;;
      *) apigee_die "unknown option $1" ;;
    esac
  done
  [[ -n "$proxy" ]] || apigee_die "usage: apigee product find --proxy PROXY"
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    if apigee_get "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$n")" | apigee_json values proxies | grep -Fx -- "$proxy" >/dev/null; then
      printf '%s\n' "$n"
    fi
  done < <(apigee_get "$(apigee_org_path)/apiproducts" | apigee_json names | sort)
}

credential_help() { prov_help credential "${1:-}" || apigee_die "unknown credential verb '$1'"; }
