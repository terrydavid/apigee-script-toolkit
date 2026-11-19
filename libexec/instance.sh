# shellcheck shell=bash
#
# Runtime instances of an Apigee X/hybrid organization:
#   apigee instance list
#   apigee instance attachments INSTANCE
#   apigee instance attach INSTANCE          (attaches --env; mutating)
#
# An environment only runs deployments once it is attached to an instance. A new
# environment that is not attached shows every deployment as ERROR with
# "no instances are reporting status for this environment".

instance_verbs() { printf '%s\n' list attachments attach; }

instance_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee instance <verb>   (Apigee X/hybrid only)\n\nVerbs:\n  list                 List runtime instances\n  attachments INSTANCE Show which environments are attached to an instance\n  attach INSTANCE      Attach --env to an instance (mutating; asks for confirmation)\n\nAn environment only runs deployments once it is attached to an instance.\n' ;;
    list) printf 'Usage: apigee instance list\n\nList the runtime instances of the organization (Apigee X/hybrid only).\n' ;;
    attachments) printf 'Usage: apigee instance attachments INSTANCE\n\nShow the environments attached to INSTANCE (read-only).\n' ;;
    attach) printf 'Usage: apigee instance attach INSTANCE   (uses --env)\n\nAttach the environment to an instance so that deployments can run. This is a\nlong-running operation: it can take several minutes (check with\n"apigee instance attachments INSTANCE"). Mutating: asks for confirmation;\n-n/--dry-run shows the request.\n' ;;
    *) apigee_die "unknown instance verb '$1'" ;;
  esac
}

instance_main() {
  apigee_require_platform x "apigee instance"
  local verb="${1:-}" inst="${2:-}" body path
  case "$verb" in
    list)
      body="$(apigee_get "$(apigee_org_path)/instances")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    attachments)
      [[ -n "$inst" ]] || apigee_die "missing INSTANCE"
      apigee_get "$(apigee_org_path)/instances/$(apigee_urlencode "$inst")/attachments" | apigee_json pretty
      ;;
    attach)
      [[ -n "$inst" ]] || apigee_die "missing INSTANCE"
      path="$(apigee_org_path)/instances/$(apigee_urlencode "$inst")/attachments"
      body="$(printf '{"environment":"%s"}' "$(apigee_env)")"
      apigee_confirm "Attach environment '$(apigee_env)' to instance '$inst' in org '$(apigee_org)'."
      apigee_request POST "$path" --json "$body" | apigee_json pretty
      ;;
    *) apigee_die "unknown instance verb '$verb' (see 'apigee instance --help')" ;;
  esac
}
