# shellcheck shell=bash
#
# Administration verbs: users, roles (RBAC), environment and organization
# lifecycle, whole-proxy delete, and environment resource files.
# Replaces createUser, deleteUser, getUserRoles/listUserRoles, createUserRole,
# deleteUserRole, addUserRole, listRBACResources, createEnvironment,
# deleteEnvironment, deleteOrganization (OPDK), loadResource and getResources.
# New-user passwords come from APIGEE_NEW_USER_PASSWORD, never from arguments.

role_verbs() { printf '%s\n' list create delete add-user remove-user users permissions; }
resourcefile_verbs() { printf '%s\n' list get upload delete revision; }

admin_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

admin_help() { # resource verb -> 0 when handled
  case "$1 ${2:-}" in
    "user create") printf 'Usage: apigee user create EMAIL --first NAME --last NAME\n\nCreate a user. The password comes from APIGEE_NEW_USER_PASSWORD (never an argument).\nMutating (Apigee Edge/OPDK only): asks for confirmation.\n' ;;
    "user delete") printf 'Usage: apigee user delete EMAIL\n\nDelete a user. Mutating (Apigee Edge/OPDK only): asks for confirmation.\n' ;;
    "user roles") printf 'Usage: apigee user roles EMAIL\n\nList the roles of a user in --org (Apigee Edge/OPDK only).\n' ;;
    "env create") printf 'Usage: apigee env create NAME\n\nCreate an environment. Mutating: asks for confirmation.\n' ;;
    "env delete") printf 'Usage: apigee env delete NAME\n\nDelete an environment (remove its deployments first). Mutating: asks for confirmation.\n' ;;
    "org delete") printf 'Usage: apigee org delete --confirm-name ORG\n\nDelete the organization (Apigee OPDK only). --confirm-name must equal --org even with --yes.\nUse --dry-run to see the request first.\n' ;;
    "role ") printf 'Usage: apigee role <verb>   (Apigee Edge/OPDK only)\n\nVerbs:\n  list                    List roles\n  create NAME             Create a role\n  delete NAME             Delete a role\n  add-user ROLE EMAIL     Give a user a role\n  remove-user ROLE EMAIL  Take a role from a user\n  users ROLE              List the users of a role\n  permissions ROLE        Show the role'"'"'s resource permissions\n\nMutating verbs ask for confirmation unless --yes.\n' ;;
    "role "*) printf 'Usage: apigee role %s ...\n\nSee "apigee role --help". Apigee Edge/OPDK only; mutating verbs ask for confirmation.\n' "$2" ;;
    "resourcefile ") printf 'Usage: apigee resourcefile <verb>   (uses --env)\n\nVerbs:\n  list [--scope org]     "type name" per resource file (--env, or the org with --scope org)\n  revision PROXY REV       Resources inside a proxy revision\n  get TYPE NAME            Print a resource file\n  upload TYPE FILE [--name N]  Upload FILE (types: jsc java py node xsl wsdl xsd properties)\n  delete TYPE NAME         Delete a resource file\n\nMutating verbs ask for confirmation unless --yes.\n' ;;
    "resourcefile "*) admin_help resourcefile "" ;;
    "proxy delete" | "sharedflow delete") printf 'Usage: apigee %s delete NAME\n\nDelete the whole %s (all revisions). Refuses while any revision is deployed.\nMutating: asks for confirmation.\n' "$1" "$1" ;;
    *) return 1 ;;
  esac
}

role_help() { admin_help role "${1:-}" || apigee_die "unknown role verb '$1'"; }
resourcefile_help() { admin_help resourcefile "${1:-}" || apigee_die "unknown resourcefile verb '$1'"; }

# --- users -----------------------------------------------------------------------

user_write() {
  local verb="$1" email="" first="" last="" pw
  shift
  while (($#)); do
    case "$1" in
      --first) first="${2:?}"; shift 2 ;;
      --last) last="${2:?}"; shift 2 ;;
      -*) apigee_die "unknown option $1 (the password comes from APIGEE_NEW_USER_PASSWORD)" ;;
      *) email="$1"; shift ;;
    esac
  done
  [[ -n "$email" ]] || apigee_die "missing EMAIL"
  case "$verb" in
    create)
      pw="${APIGEE_NEW_USER_PASSWORD:-}"
      [[ -n "$pw" ]] || apigee_die "no password: set APIGEE_NEW_USER_PASSWORD (passwords are never taken as arguments)"
      [[ -n "$first" ]] || first="${email%%@*}"
      [[ -n "$last" ]] || last="User"
      apigee_confirm "Create user '$email'."
      apigee_request POST "/users" --json "{\"emailId\":\"$(admin_esc "$email")\",\"firstName\":\"$(admin_esc "$first")\",\"lastName\":\"$(admin_esc "$last")\",\"password\":\"$(admin_esc "$pw")\"}" \
        | apigee_json omit password | apigee_json pretty
      ;;
    delete)
      apigee_confirm "Delete user '$email'."
      apigee_request DELETE "/users/$(apigee_urlencode "$email")" >/dev/null
      apigee_info "deleted user $email"
      ;;
    roles)
      apigee_get "$(apigee_org_path)/users/$(apigee_urlencode "$email")/userroles" | apigee_json names role
      ;;
  esac
}

# --- roles ---------------------------------------------------------------------------

role_main() {
  apigee_require_platform edge "apigee role (X/hybrid roles are Cloud IAM roles)"
  local verb="${1:-}" role="${2:-}" email="${3:-}" base
  shift || true
  case "$verb" in
    "" | -h | --help | help) admin_help role ""; return 0 ;;
  esac
  base="$(apigee_org_path)/userroles"
  case "$verb" in
    list) apigee_get "$base" | apigee_json names | sort ;;
    create)
      [[ -n "$role" ]] || apigee_die "missing NAME"
      apigee_confirm "Create role '$role' in org '$(apigee_org)'."
      apigee_request POST "$base" --json "{\"role\":[{\"name\":\"$(admin_esc "$role")\"}]}" | apigee_json pretty
      ;;
    delete)
      [[ -n "$role" ]] || apigee_die "missing NAME"
      apigee_confirm "Delete role '$role' in org '$(apigee_org)'."
      apigee_request DELETE "$base/$(apigee_urlencode "$role")" >/dev/null
      apigee_info "deleted role $role"
      ;;
    add-user)
      [[ -n "$role" && -n "$email" ]] || apigee_die "usage: apigee role add-user ROLE EMAIL"
      apigee_confirm "Give '$email' the role '$role' in org '$(apigee_org)'."
      apigee_request POST "$base/$(apigee_urlencode "$role")/users?id=$(apigee_urlencode "$email")" --content-type application/x-www-form-urlencoded >/dev/null
      apigee_info "added $email to role $role"
      ;;
    remove-user)
      [[ -n "$role" && -n "$email" ]] || apigee_die "usage: apigee role remove-user ROLE EMAIL"
      apigee_confirm "Remove '$email' from role '$role' in org '$(apigee_org)'."
      apigee_request DELETE "$base/$(apigee_urlencode "$role")/users/$(apigee_urlencode "$email")" >/dev/null
      apigee_info "removed $email from role $role"
      ;;
    users)
      [[ -n "$role" ]] || apigee_die "missing ROLE"
      apigee_get "$base/$(apigee_urlencode "$role")/users" | apigee_json names | sort
      ;;
    permissions)
      [[ -n "$role" ]] || apigee_die "missing ROLE"
      apigee_get "$base/$(apigee_urlencode "$role")/permissions" | apigee_json pretty
      ;;
    *) apigee_die "unknown role verb '$verb' (see 'apigee role --help')" ;;
  esac
}

# --- environment / organization lifecycle -----------------------------------------------

env_lifecycle() { # create|delete NAME
  local verb="$1" name="${2:-}"
  [[ -n "$name" ]] || apigee_die "missing NAME"
  case "$verb" in
    create)
      apigee_confirm "Create environment '$name' in org '$(apigee_org)'."
      apigee_request POST "$(apigee_org_path)/environments" --json "{\"name\":\"$(admin_esc "$name")\"}" | apigee_json pretty
      ;;
    delete)
      apigee_confirm "Delete environment '$name' in org '$(apigee_org)'."
      apigee_request DELETE "$(apigee_org_path)/environments/$(apigee_urlencode "$name")" >/dev/null
      apigee_info "deleted environment $name"
      ;;
  esac
}

org_delete() {
  apigee_require_platform opdk "apigee org delete"
  local confirm=""
  while (($#)); do
    case "$1" in
      --confirm-name) confirm="${2:?--confirm-name needs the org name}"; shift 2 ;;
      *) apigee_die "unknown option $1" ;;
    esac
  done
  [[ -n "${APIGEE_ORG:-}" ]] || apigee_die "APIGEE_ORG is not set (use --org or a profile)"
  [[ "$confirm" == "$APIGEE_ORG" ]] || apigee_die "refusing to delete org '$APIGEE_ORG': pass --confirm-name $APIGEE_ORG to confirm"
  apigee_confirm "DELETE THE ENTIRE ORGANIZATION '$APIGEE_ORG' (all proxies, apps, developers and environments). This cannot be undone."
  apigee_request DELETE "$(apigee_org_path)" >/dev/null
  [[ "$APIGEE_DRY_RUN" == 1 ]] || apigee_info "deleted organization $APIGEE_ORG"
}

# --- whole-bundle delete ----------------------------------------------------------------------

bundle_delete_all() {
  local label="$1" name="${2:-}" deployed
  bundle_require_name "$label" "$name" delete
  deployed="$(bundle_deployed_all "$label" "$name")" || exit 1
  if [[ -n "$deployed" ]]; then
    printf '%s\n' "$deployed" >&2
    apigee_die "$label '$name' is still deployed (listed above as ENV REVISION); undeploy it first"
  fi
  apigee_confirm "Delete $label '$name' and ALL of its revisions in org '$(apigee_org)'."
  apigee_request DELETE "$(bundle_path "$label" "$name")" >/dev/null
  [[ "$APIGEE_DRY_RUN" == 1 ]] || apigee_info "deleted $label $name"
}

# --- resource files --------------------------------------------------------------------------------

resourcefile_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    "" | -h | --help | help) admin_help resourcefile ""; return 0 ;;
  esac
  local base type="${1:-}" name="${2:-}"
  case "$verb" in
    list | get | upload | delete) base="$(apigee_env_path)/resourcefiles" ;;
  esac
  case "$verb" in
    list)
      if [[ "$type" == --scope && "$name" == org ]]; then base="$(apigee_org_path)/resourcefiles"; fi
      apigee_get "$base" | apigee_json resourcefiles
      ;;
    revision)
      [[ -n "$type" && -n "$name" ]] || apigee_die "usage: apigee resourcefile revision PROXY REV"
      apigee_get "$(apigee_org_path)/apis/$(apigee_urlencode "$type")/revisions/$(apigee_urlencode "$name")/resources" | apigee_json names
      ;;
    get)
      [[ -n "$type" && -n "$name" ]] || apigee_die "usage: apigee resourcefile get TYPE NAME"
      apigee_request GET "$base/$type/$(apigee_urlencode "$name")" --accept '*/*'
      ;;
    upload)
      local file="${2:-}" rname=""
      [[ -n "$type" && -n "$file" ]] || apigee_die "usage: apigee resourcefile upload TYPE FILE [--name N]"
      shift 2
      while (($#)); do
        case "$1" in
          --name) rname="${2:?}"; shift 2 ;;
          *) apigee_die "unknown option $1" ;;
        esac
      done
      [[ -f "$file" ]] || apigee_die "no such file: $file"
      rname="${rname:-$(basename "$file")}"
      apigee_confirm "Upload resource file '$rname' ($type) to '$(apigee_env)'."
      apigee_request POST "$base?name=$(apigee_urlencode "$rname")&type=$(apigee_urlencode "$type")" --form "file=@$file" | apigee_json pretty
      ;;
    delete)
      [[ -n "$type" && -n "$name" ]] || apigee_die "usage: apigee resourcefile delete TYPE NAME"
      apigee_confirm "Delete resource file '$name' ($type) from '$(apigee_env)'."
      apigee_request DELETE "$base/$type/$(apigee_urlencode "$name")" >/dev/null
      apigee_info "deleted resource file $name"
      ;;
    *) apigee_die "unknown resourcefile verb '$verb' (see 'apigee resourcefile --help')" ;;
  esac
}

# --- audit (orphan finder) and raw API --------------------------------------------------

audit_verbs() { printf '%s\n' products apps; }
raw_verbs() { printf '%s\n' GET POST PUT DELETE; }

audit_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee audit <verb>\n\nVerbs:\n  products   API products that list a proxy which no longer exists ("PRODUCT PROXY")\n  apps       App credentials that reference an API product which no longer exists ("APP PRODUCT")\n\nPrints findings, exits 1 when any are found. Replaces findBrokenProducts/findBrokenApiProxies/findBrokenApps.\n' ;;
    products | apps) audit_help "" ;;
    *) apigee_die "unknown audit verb '$1'" ;;
  esac
}

raw_help() {
  printf 'Usage: apigee raw METHOD PATH [--json BODY | --data-file FILE] [--ok CODES]\n\nCall any management API path under the selected platform (PATH starts with /).\nGET prints the JSON; other methods ask for confirmation. Absolute URLs are refused so\ncredentials only go to the configured management host.\n'
}

audit_main() {
  local verb="${1:-}" findings="" p n known prods
  case "$verb" in
    "" | -h | --help | help) audit_help ""; return 0 ;;
    products)
      known="$(apigee_get "$(apigee_org_path)/apis" | apigee_json names proxies | sort -u)" || exit 1
      prods="$(apigee_get "$(apigee_org_path)/apiproducts" | apigee_json names apiProduct)" || exit 1
      while IFS= read -r n; do
        [[ -n "$n" ]] || continue
        while IFS= read -r p; do
          [[ -n "$p" ]] || continue
          printf '%s\n' "$known" | grep -Fx -- "$p" >/dev/null || findings="$findings$n $p"$'\n'
        done < <(apigee_get "$(apigee_org_path)/apiproducts/$(apigee_urlencode "$n")" | apigee_json values proxies)
      done <<EOF
$prods
EOF
      ;;
    apps)
      known="$(apigee_get "$(apigee_org_path)/apiproducts" | apigee_json names apiProduct | sort -u)" || exit 1
      while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        printf '%s\n' "$known" | grep -Fx -- "${p#* }" >/dev/null || findings="$findings$p"$'\n'
      done < <(apigee_get "$(apigee_org_path)/apps?expand=true" | apigee_json app-products)
      ;;
    *) apigee_die "unknown audit verb '$verb' (see 'apigee audit --help')" ;;
  esac
  if [[ -n "$findings" ]]; then
    printf '%s' "$findings"
    return 1
  fi
  apigee_info "audit $verb: nothing broken"
}

raw_main() {
  local method="${1:-}" path="${2:-}"
  case "$method" in
    "" | -h | --help | help) api_help; return 0 ;;
  esac
  [[ -n "$path" ]] || apigee_die "usage: apigee raw METHOD PATH [--json BODY | --data-file FILE]"
  shift 2
  method="$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]')"
  [[ "$path" == /* ]] || apigee_die "PATH must start with / (absolute URLs are refused)"
  case "$method" in
    GET) apigee_request GET "$path" "$@" | apigee_json pretty ;;
    POST | PUT | DELETE | PATCH)
      apigee_confirm "$method $path on $(apigee_platform_label) org '${APIGEE_ORG:-?}'."
      apigee_request "$method" "$path" "$@"
      ;;
    *) apigee_die "unsupported method '$method'" ;;
  esac
}
