# shellcheck shell=bash
#
# apigee token  — print an access token for the selected platform.
# apigee profile list|use|show|current|clear — named configuration profiles.

token_verbs() { printf '%s\n' print header; }

token_help() {
  case "${1:-}" in
    "" | print | header)
      cat <<'EOF'
Usage: apigee token [--header]

Print a bearer token for the selected platform to stdout, for piping into
other tools (X/hybrid: gcloud auth print-access-token; Edge: OAuth2 via the
Edge token endpoint, cached until it expires). --header prints a complete
"Authorization: Bearer ..." line. Not available with Edge basic auth.
EOF
      ;;
    *) apigee_die "unknown token option '$1'" ;;
  esac
}

token_main() {
  case "${1:-print}" in
    print) apigee_token ;;
    header | --header) printf 'Authorization: Bearer %s\n' "$(apigee_token)" ;;
    *) apigee_die "unknown token option '$1' (see 'apigee token --help')" ;;
  esac
}

profile_verbs() { printf '%s\n' list use show current clear; }

profile_help() {
  case "${1:-}" in
    "")
      cat <<'EOF'
Usage: apigee profile <verb>

Verbs:
  list           List available profiles (* marks the active one)
  use NAME       Make NAME the default profile for future commands
  show [NAME]    Print a profile's settings (default: active profile)
  current        Print the active profile name
  clear          Forget the default profile

Profiles are files named NAME.env in ~/.config/apigee-toolkit/profiles/ or
config/profiles/ (see config/apigee.env.example). They hold settings only:
never put passwords or tokens in them. Variables already exported in your
shell win over the default profile; use --profile NAME, or
'source bin/apigee-env NAME', to switch explicitly.
EOF
      ;;
    list) printf 'Usage: apigee profile list\n' ;;
    use) printf 'Usage: apigee profile use NAME\n\nRecord NAME as the default profile (stored in ~/.config/apigee-toolkit/current-profile).\n' ;;
    show)
      cat <<'EOF'
Usage: apigee profile show [NAME]

Print the settings in a profile file. The value of any variable whose name
contains SECRET, PASSWORD, PASSCODE, TOKEN, CLIENT, MFA or KEY (any case) is
shown as <redacted>.
EOF
      ;;
    current) printf 'Usage: apigee profile current\n' ;;
    clear) printf 'Usage: apigee profile clear\n' ;;
    *) apigee_die "unknown profile verb '$1' (see 'apigee profile --help')" ;;
  esac
}

# Variable names that may hold credentials (matched case-insensitively).
PROFILE_SECRET_NAME_RE='SECRET|PASSWORD|PASSCODE|TOKEN|CLIENT|MFA|KEY'

# Print the assignments of a profile file; values of secret-looking variables
# are replaced by <redacted>.
profile_show_redacted() {
  local line var upper
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)= ]] || continue
    var="${BASH_REMATCH[2]}"
    upper="$(printf '%s' "$var" | tr '[:lower:]' '[:upper:]')"
    if [[ "$upper" =~ $PROFILE_SECRET_NAME_RE ]]; then
      printf '%s=<redacted>\n' "$var"
    else
      printf '%s\n' "$line"
    fi
  done <"$1"
}

profile_main() {
  local verb="${1:-list}" name dir f current
  shift || true
  current="$(apigee_current_profile_name)"
  case "$verb" in
    list)
      while IFS= read -r dir; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/*.env; do
          [[ -f "$f" ]] || continue
          name="$(basename "$f" .env)"
          if [[ "$name" == "$current" ]]; then
            printf '* %-20s %s\n' "$name" "$f"
          else
            printf '  %-20s %s\n' "$name" "$f"
          fi
        done
      done <<EOF
$(apigee_profile_dirs)
EOF
      ;;
    use)
      name="${1:-}"
      [[ -n "$name" ]] || apigee_die "missing NAME"
      apigee_profile_file "$name" >/dev/null || apigee_die "profile '$name' not found (see 'apigee profile list')"
      mkdir -p "$(apigee_config_home)"
      printf '%s\n' "$name" >"$(apigee_config_home)/current-profile"
      apigee_info "default profile is now '$name'"
      ;;
    show)
      name="${1:-$current}"
      [[ -n "$name" ]] || apigee_die "no active profile"
      f="$(apigee_profile_file "$name")" || apigee_die "profile '$name' not found"
      printf '# %s\n' "$f"
      profile_show_redacted "$f"
      ;;
    current) [[ -n "$current" ]] && printf '%s\n' "$current" ;;
    clear)
      rm -f "$(apigee_config_home)/current-profile"
      apigee_info "default profile cleared"
      ;;
    *) apigee_die "unknown profile verb '$verb' (see 'apigee profile --help')" ;;
  esac
}

# apigee sa create|status|undo — a service account the toolkit runs as (no hourly re-login).
sa_verbs() { printf '%s\n' create status undo; }

sa_help() {
  cat <<'EOF'
Usage: apigee sa create [--name NAME] [--role ROLE]... [--read-only] [--save-profile NAME] [--dry-run]
       apigee sa status
       apigee sa undo

create  makes SA NAME (default apigee-toolkit) in the org's project, grants it the roles
        (default roles/apigee.admin), lets CLOUDSDK_CORE_ACCOUNT impersonate it, checks a
        token really belongs to it, then switches gcloud to it (setup/gcloud-impersonate.sh).
        --save-profile NAME instead writes CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT into
        that profile, leaving gcloud's own configuration alone.
status  shows the service account gcloud will use for toolkit commands.
undo    stops impersonating in the active gcloud configuration.
For one command only: apigee --impersonate SA_EMAIL ...
EOF
}

sa_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    status)
      local cur="${CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT:-}"
      [[ -n "$cur" ]] || cur="$(gcloud config get-value auth/impersonate_service_account 2>/dev/null || true)"
      if [[ -n "$cur" && "$cur" != "(unset)" ]]; then printf 'impersonating %s\n' "$cur"; else printf 'not impersonating (using the gcloud login)\n'; fi
      ;;
    undo)
      local args=(--undo)
      [[ "$APIGEE_DRY_RUN" == 1 ]] && args+=(-n)
      "$APIGEE_TOOLKIT_HOME/setup/gcloud-impersonate.sh" "${args[@]}"
      ;;
    create)
      local name=apigee-toolkit save="" args=() project="${APIGEE_ORG:-}"
      while (($#)); do
        case "$1" in
          --name) name="${2:?--name needs a value}"; shift 2 ;;
          --role) args+=(--role "${2:?--role needs a value}"); shift 2 ;;
          --read-only) args+=(--read-only); shift ;;
          --save-profile) save="${2:?--save-profile needs a value}"; shift 2 ;;
          --dry-run | -n) APIGEE_DRY_RUN=1; shift ;;
          *) apigee_die "unknown sa create option '$1'" ;;
        esac
      done
      [[ -n "$project" ]] || apigee_die "no project: set APIGEE_ORG or pass --org"
      [[ "$name" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || apigee_die "invalid service account name '$name'"
      local sa="$name@$project.iam.gserviceaccount.com" user="${CLOUDSDK_CORE_ACCOUNT:-}"
      [[ -n "$user" ]] || user="$(gcloud config get-value account 2>/dev/null || true)"
      [[ -n "$user" ]] || apigee_die "no login to start from: set CLOUDSDK_CORE_ACCOUNT"
      apigee_confirm "Create service account $sa and let $user impersonate it."
      args+=(--project "$project" --sa "$name" --user "$user" --yes)
      [[ "$APIGEE_DRY_RUN" == 1 ]] && args+=(-n)
      [[ -n "$save" ]] && args+=(--no-config)
      "$APIGEE_TOOLKIT_HOME/setup/gcloud-impersonate.sh" "${args[@]}" || exit 1
      if [[ -n "$save" ]]; then
        [[ "$save" =~ ^[A-Za-z0-9._-]+$ ]] || apigee_die "invalid profile name '$save'"
        local dir="${APIGEE_CONFIG_HOME:-$HOME/.config/apigee-toolkit}/profiles" f
        f="$dir/$save.env"
        mkdir -p "$dir"
        { [[ -f "$f" ]] && grep -v '^CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=' "$f" || true
          grep -q '^APIGEE_ORG=' "$f" 2>/dev/null || printf 'APIGEE_ORG=%s\n' "$project"
          printf 'CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=%s\n' "$sa"; } >"$f.new" && mv "$f.new" "$f"
        printf 'saved to %s; use it with: apigee --profile %s ...\n' "$f" "$save"
      fi
      ;;
    *) apigee_die "unknown sa verb '$verb' (see 'apigee sa --help')" ;;
  esac
}
