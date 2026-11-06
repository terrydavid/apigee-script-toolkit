#!/usr/bin/env bash
#
# Verify apigee-toolkit configuration and authentication for the selected
# platform with a single read-only call (GET organization). Prints a fix for
# every problem found. Exit status 0 when everything works.
#
#   setup/doctor.sh [--profile NAME] [--platform x|edge] [--org ORG] [--env ENV]
#
set -uo pipefail

APIGEE_TOOLKIT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export APIGEE_TOOLKIT_HOME
# shellcheck source=../lib/platform.sh
. "$APIGEE_TOOLKIT_HOME/lib/platform.sh"
# shellcheck source=../lib/json.sh
. "$APIGEE_TOOLKIT_HOME/lib/json.sh"

profile="" cli_platform="" cli_org="" cli_env=""
while (($#)); do
  case "$1" in
    --profile) profile="$2"; shift 2 ;;
    --platform) cli_platform="$2"; shift 2 ;;
    --org) cli_org="$2"; shift 2 ;;
    --env) cli_env="$2"; shift 2 ;;
    -h | --help) sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'doctor: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done

problems=0
ok() { printf '  [ok]   %s\n' "$*"; }
bad() {
  printf '  [FAIL] %s\n' "$1"
  shift
  local fix
  for fix in "$@"; do printf '         fix: %s\n' "$fix"; done
  problems=$((problems + 1))
}

apigee_init_tmpdir
printf 'apigee-toolkit doctor\n'
(apigee_load_config "$profile") || bad "could not load configuration" "check the profile name with 'bin/apigee profile list'"
apigee_load_config "$profile" 2>/dev/null || true
[[ -n "$cli_platform" ]] && APIGEE_PLATFORM="$cli_platform"
[[ -n "$cli_org" ]] && APIGEE_ORG="$cli_org"
[[ -n "$cli_env" ]] && APIGEE_ENV="$cli_env"

printf '\nTools\n'
if apigee_have curl; then ok "curl $(curl --version | head -n 1 | awk '{print $2}')"; else bad "curl missing" "setup/install.sh"; fi
if apigee_have jq; then
  ok "jq present"
elif apigee_have python3; then
  ok "python3 present (jq not found; using the python fallback)"
else
  bad "neither jq nor python3 found" "setup/install.sh"
fi

printf '\nConfiguration\n'
if [[ -n "${APIGEE_PROFILE:-$(apigee_current_profile_name)}" ]]; then
  ok "profile: ${APIGEE_PROFILE:-$(apigee_current_profile_name)}"
fi
case "${APIGEE_PLATFORM:-}" in
  x | X | hybrid | apigee-x | edge | Edge | EDGE | opdk) ok "APIGEE_PLATFORM=$APIGEE_PLATFORM" ;;
  "") bad "APIGEE_PLATFORM is not set" "export APIGEE_PLATFORM=x (or edge), or create a profile from config/apigee.env.example" ;;
  *) bad "APIGEE_PLATFORM='$APIGEE_PLATFORM' is not supported" "use x, hybrid or edge" ;;
esac
if [[ -n "${APIGEE_ORG:-}" ]]; then ok "APIGEE_ORG=$APIGEE_ORG"; else bad "APIGEE_ORG is not set" "export APIGEE_ORG=<org> or set it in your profile"; fi
if [[ -n "${APIGEE_ENV:-}" ]]; then ok "APIGEE_ENV=$APIGEE_ENV"; else printf '  [warn] APIGEE_ENV is not set (needed by environment-scoped commands)\n'; fi

if ((problems > 0)); then
  printf '\n%d problem(s) found; fix the configuration first.\n' "$problems"
  exit 1
fi

apigee_platform_init
printf '\nPlatform: %s  (%s)\n' "$(apigee_platform_label)" "$APIGEE_BASE_URL"

printf '\nAuthentication\n'
if [[ -n "${APIGEE_TOKEN:-}" ]]; then
  ok "using APIGEE_TOKEN from the environment"
elif [[ "$APIGEE_KIND" == x ]]; then
  if ! apigee_have gcloud; then
    bad "gcloud not found" "setup/install.sh (or brew install --cask google-cloud-sdk)"
  else
    account="${CLOUDSDK_CORE_ACCOUNT:-$(gcloud config get-value account 2>/dev/null)}"
    if [[ -n "$account" ]]; then ok "gcloud account: $account"; else bad "no active gcloud account" "gcloud auth login"; fi
    if (apigee_token >/dev/null 2>&1); then ok "gcloud issued an access token"; else bad "gcloud could not issue a token" "gcloud auth login${account:+ $account}"; fi
  fi
else
  mode="$(apigee_edge_auth_mode)"
  ok "Edge auth mode: $mode"
  if [[ -z "${APIGEE_EDGE_USER:-}" && -z "${APIGEE_EDGE_PASSCODE:-}" ]]; then
    bad "APIGEE_EDGE_USER is not set" "set APIGEE_EDGE_USER in your profile"
  elif ! (apigee_edge_password >/dev/null 2>&1) && [[ -z "${APIGEE_EDGE_PASSCODE:-}" ]]; then
    bad "no Edge password found" \
      "security add-generic-password -U -s '${APIGEE_EDGE_KEYCHAIN_SERVICE:-$APIGEE_EDGE_KEYCHAIN_SERVICE_DEFAULT}' -a '${APIGEE_EDGE_USER:-}' -w" \
      "or export APIGEE_EDGE_PASSWORD for this shell only"
  else
    ok "Edge credentials found (not shown)"
  fi
  if [[ "$mode" == oauth ]]; then
    if (apigee_secret APIGEE_EDGE_SSO_CLIENT "${APIGEE_EDGE_SSO_KEYCHAIN_SERVICE:-$APIGEE_EDGE_SSO_KEYCHAIN_SERVICE_DEFAULT}" client >/dev/null 2>&1); then
      ok "Edge SSO client credentials found (not shown)"
    else
      bad "no Edge SSO client credentials" \
        "security add-generic-password -U -s '${APIGEE_EDGE_SSO_KEYCHAIN_SERVICE:-$APIGEE_EDGE_SSO_KEYCHAIN_SERVICE_DEFAULT}' -a client -w" \
        "(value is client_id:client_secret as documented for Apigee's get_token utility), or use APIGEE_EDGE_AUTH=basic"
    fi
  fi
fi

if ((problems > 0)); then
  printf '\n%d problem(s) found.\n' "$problems"
  exit 1
fi

printf '\nRead-only API check\n'
if body="$(apigee_get "$(apigee_org_path)" 2>"$APIGEE_TMPDIR/doctor.err")"; then
  name="$(printf '%s' "$body" | apigee_json get name)"
  ok "GET organization '${name:-$APIGEE_ORG}' succeeded"
else
  code="$(apigee_last_status)"
  case "$code" in
    401) bad "HTTP 401 (unauthenticated)" "re-authenticate (gcloud auth login / check the Edge password or token URL)" ;;
    403) bad "HTTP 403 (forbidden) for org '$APIGEE_ORG'" "check the org name and that your account has an Apigee role on it" ;;
    404) bad "HTTP 404: org '$APIGEE_ORG' not found at $APIGEE_BASE_URL" "check APIGEE_ORG and the platform/base URL" ;;
    *) bad "request failed (HTTP ${code:-n/a}): $(head -c 300 "$APIGEE_TMPDIR/doctor.err")" "check network access to $APIGEE_BASE_URL" ;;
  esac
fi

if [[ -n "${APIGEE_ENV:-}" && "$problems" == 0 ]]; then
  if apigee_get "$(apigee_env_path)" >/dev/null 2>"$APIGEE_TMPDIR/doctor.err"; then
    ok "environment '$APIGEE_ENV' exists"
  else
    bad "environment '$APIGEE_ENV' not readable (HTTP $(apigee_last_status))" "list environments with: bin/apigee env list"
  fi
fi

if ((problems > 0)); then
  printf '\n%d problem(s) found.\n' "$problems"
  exit 1
fi
printf '\nAll checks passed.\n'
