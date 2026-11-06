# shellcheck shell=bash
#
# Platform abstraction for Apigee X/hybrid and Apigee Edge.
#
# Sourced by bin/apigee, setup/doctor.sh and the tests. Must stay compatible
# with the bash 3.2 that ships with macOS (no associative arrays, no mapfile,
# guard empty-array expansion under `set -u`).

APIGEE_X_API_URL_DEFAULT="https://apigee.googleapis.com/v1"
APIGEE_EDGE_MGMT_URL_DEFAULT="https://api.enterprise.apigee.com"
APIGEE_EDGE_TOKEN_URL_DEFAULT="https://login.apigee.com/oauth/token"
APIGEE_EDGE_KEYCHAIN_SERVICE_DEFAULT="apigee-toolkit-edge"
APIGEE_EDGE_SSO_KEYCHAIN_SERVICE_DEFAULT="apigee-toolkit-edge-sso-client"

APIGEE_DRY_RUN="${APIGEE_DRY_RUN:-0}"
APIGEE_YES="${APIGEE_YES:-0}"
APIGEE_DEBUG="${APIGEE_DEBUG:-0}"

# Variables a profile / env file may set. Used for "fill only unset" loading.
APIGEE_CONFIG_VARS="APIGEE_PLATFORM APIGEE_ORG APIGEE_ENV APIGEE_X_API_URL
APIGEE_EDGE_MGMT_URL APIGEE_EDGE_AUTH APIGEE_EDGE_USER APIGEE_EDGE_TOKEN_URL
APIGEE_EDGE_KEYCHAIN_SERVICE APIGEE_EDGE_SSO_KEYCHAIN_SERVICE
APIGEE_KVM_READER_URL APIGEE_KVM_READER_AUTH APIGEE_JSON_ENGINE
APIGEE_NO_TOKEN_CACHE CLOUDSDK_CORE_ACCOUNT"

apigee_die() {
  printf 'apigee: error: %s\n' "$*" >&2
  exit 1
}

apigee_warn() {
  printf 'apigee: warning: %s\n' "$*" >&2
}

apigee_info() {
  printf '%s\n' "$*" >&2
}

apigee_debug() {
  if [[ "$APIGEE_DEBUG" == 1 ]]; then
    printf 'apigee: debug: %s\n' "$*" >&2
  fi
  return 0
}

# Write stdin to the user's terminal stdout even from inside $(...) or a
# redirected call: bin/apigee duplicates the original stdout to fd 3.
apigee_user_out() {
  if { true >&3; } 2>/dev/null; then
    cat >&3
  else
    cat
  fi
}

apigee_have() {
  command -v "$1" >/dev/null 2>&1
}

apigee_config_home() {
  printf '%s\n' "${APIGEE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/apigee-toolkit}"
}

apigee_cache_home() {
  printf '%s\n' "${APIGEE_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/apigee-toolkit}"
}

# ---------------------------------------------------------------------------
# Configuration / profiles
# ---------------------------------------------------------------------------

apigee_profile_dirs() {
  printf '%s\n' "$(apigee_config_home)/profiles"
  printf '%s\n' "$APIGEE_TOOLKIT_HOME/config/profiles"
}

apigee_profile_file() {
  local name="$1" dir
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || apigee_die "invalid profile name '$name'"
  while IFS= read -r dir; do
    if [[ -f "$dir/$name.env" ]]; then
      printf '%s\n' "$dir/$name.env"
      return 0
    fi
  done <<EOF
$(apigee_profile_dirs)
EOF
  return 1
}

# Source an env file. mode=fill keeps any variable already set in the
# environment; mode=override lets the file win.
apigee_load_env_file() {
  local file="$1" mode="${2:-fill}" var saved=""
  [[ -f "$file" ]] || apigee_die "config file not found: $file"
  if [[ "$mode" == fill ]]; then
    for var in $APIGEE_CONFIG_VARS; do
      if [[ -n "${!var+x}" ]]; then
        saved="$saved$var=$(printf '%q' "${!var}")
"
      fi
    done
  fi
  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
  if [[ -n "$saved" ]]; then
    eval "$saved"
  fi
}

apigee_current_profile_name() {
  local state
  state="$(apigee_config_home)/current-profile"
  if [[ -n "${APIGEE_PROFILE:-}" ]]; then
    printf '%s\n' "$APIGEE_PROFILE"
  elif [[ -s "$state" ]]; then
    head -n 1 "$state"
  fi
}

# Load configuration in precedence order (lowest first):
#   config/apigee.env (repo) -> $APIGEE_CONFIG_HOME/apigee.env -> implicit
#   profile (APIGEE_PROFILE or `apigee profile use`) -> environment ->
#   explicit --profile -> CLI flags (applied by the caller afterwards).
apigee_load_config() {
  local explicit_profile="${1:-}" implicit file
  if [[ -n "$explicit_profile" ]]; then
    file="$(apigee_profile_file "$explicit_profile")" ||
      apigee_die "profile '$explicit_profile' not found (looked in: $(apigee_profile_dirs | tr '\n' ' '))"
    apigee_load_env_file "$file" override
    APIGEE_PROFILE="$explicit_profile"
  else
    implicit="$(apigee_current_profile_name)"
    if [[ -n "$implicit" ]]; then
      file="$(apigee_profile_file "$implicit")" ||
        apigee_die "active profile '$implicit' not found; run 'apigee profile list'"
      apigee_load_env_file "$file" fill
    fi
  fi
  for file in "$(apigee_config_home)/apigee.env" "$APIGEE_TOOLKIT_HOME/config/apigee.env"; do
    if [[ -f "$file" ]]; then
      apigee_load_env_file "$file" fill
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# Platform selection
# ---------------------------------------------------------------------------

apigee_platform_init() {
  case "${APIGEE_PLATFORM:-}" in
    x | X | hybrid | apigee-x) APIGEE_KIND=x ;;
    edge | Edge | EDGE | opdk) APIGEE_KIND=edge ;;
    "") apigee_die "APIGEE_PLATFORM is not set (use x, hybrid or edge; see config/apigee.env.example)" ;;
    *) apigee_die "unsupported APIGEE_PLATFORM '${APIGEE_PLATFORM}' (use x, hybrid or edge)" ;;
  esac
  local base
  if [[ "$APIGEE_KIND" == x ]]; then
    base="${APIGEE_X_API_URL:-$APIGEE_X_API_URL_DEFAULT}"
    base="${base%/}"
  else
    base="${APIGEE_EDGE_MGMT_URL:-$APIGEE_EDGE_MGMT_URL_DEFAULT}"
    base="${base%/}"
    base="${base%/v1}/v1"
  fi
  APIGEE_BASE_URL="$base"
  export APIGEE_KIND APIGEE_BASE_URL
}

apigee_platform_label() {
  if [[ "${1:-$APIGEE_KIND}" == x ]]; then
    printf 'Apigee X/hybrid'
  else
    printf 'Apigee Edge'
  fi
}

# apigee_require_platform x|edge "feature description"
apigee_require_platform() {
  local want="$1" what="$2"
  if [[ "$APIGEE_KIND" != "$want" ]]; then
    apigee_die "$what is not supported on $(apigee_platform_label) (only on $(apigee_platform_label "$want"))"
  fi
}

apigee_org() {
  [[ -n "${APIGEE_ORG:-}" ]] || apigee_die "APIGEE_ORG is not set (use --org or a profile)"
  printf '%s\n' "$APIGEE_ORG"
}

apigee_env() {
  [[ -n "${APIGEE_ENV:-}" ]] || apigee_die "APIGEE_ENV is not set (use --env or a profile)"
  printf '%s\n' "$APIGEE_ENV"
}

apigee_org_path() {
  [[ -n "${APIGEE_ORG:-}" ]] || apigee_die "APIGEE_ORG is not set (use --org or a profile)"
  printf '/organizations/%s\n' "$(apigee_urlencode "$APIGEE_ORG")"
}

apigee_env_path() {
  [[ -n "${APIGEE_ORG:-}" ]] || apigee_die "APIGEE_ORG is not set (use --org or a profile)"
  [[ -n "${APIGEE_ENV:-}" ]] || apigee_die "APIGEE_ENV is not set (use --env or a profile)"
  printf '/organizations/%s/environments/%s\n' "$(apigee_urlencode "$APIGEE_ORG")" "$(apigee_urlencode "$APIGEE_ENV")"
}

apigee_urlencode() {
  local s="$1" out="" c i
  local LC_ALL=C
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [A-Za-z0-9._~-]) out="$out$c" ;;
      *) out="$out$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------------------
# Temp files
# ---------------------------------------------------------------------------

# Must be called once from the top-level shell (not inside $(...)) so the
# cleanup trap belongs to the main process.
apigee_init_tmpdir() {
  if [[ -z "${APIGEE_TMPDIR:-}" || ! -d "$APIGEE_TMPDIR" ]]; then
    APIGEE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/apigee-toolkit.XXXXXX")" || apigee_die "cannot create temp dir"
    chmod 700 "$APIGEE_TMPDIR"
    export APIGEE_TMPDIR
    # shellcheck disable=SC2064
    trap "rm -rf '$APIGEE_TMPDIR'" EXIT
  fi
}

apigee_tmpdir() {
  if [[ -z "${APIGEE_TMPDIR:-}" || ! -d "$APIGEE_TMPDIR" ]]; then
    ((BASH_SUBSHELL == 0)) || apigee_die "internal: apigee_init_tmpdir was not called"
    apigee_init_tmpdir
  fi
  printf '%s\n' "$APIGEE_TMPDIR"
}

apigee_mktemp() {
  local dir
  dir="$(apigee_tmpdir)"
  mktemp "$dir/${1:-tmp}.XXXXXX"
}

# ---------------------------------------------------------------------------
# Secrets: environment variable first, then macOS Keychain. Never argv/echo.
# ---------------------------------------------------------------------------

# apigee_secret ENV_VAR_NAME KEYCHAIN_SERVICE KEYCHAIN_ACCOUNT
apigee_secret() {
  local var="$1" service="$2" account="$3"
  if [[ -n "${!var:-}" ]]; then
    printf '%s' "${!var}"
    return 0
  fi
  if apigee_have security && [[ -n "$service" ]]; then
    security find-generic-password -s "$service" -a "$account" -w 2>/dev/null && return 0
  fi
  return 1
}

# Escape a value for a double-quoted curl --config string.
apigee_curl_cfg_quote() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

apigee_edge_auth_mode() {
  if [[ -n "${APIGEE_TOKEN:-}" ]]; then
    printf 'token\n'
    return
  fi
  case "${APIGEE_EDGE_AUTH:-oauth}" in
    oauth | basic | token) printf '%s\n' "${APIGEE_EDGE_AUTH:-oauth}" ;;
    *) apigee_die "unsupported APIGEE_EDGE_AUTH '${APIGEE_EDGE_AUTH}' (use oauth, basic or token)" ;;
  esac
}

# Describes the auth that will be used, without fetching anything.
apigee_auth_description() {
  if [[ -n "${APIGEE_TOKEN:-}" ]]; then
    printf 'Authorization: Bearer <redacted> (APIGEE_TOKEN)\n'
  elif [[ "$APIGEE_KIND" == x ]]; then
    printf 'Authorization: Bearer <redacted> (gcloud auth print-access-token%s)\n' \
      "${CLOUDSDK_CORE_ACCOUNT:+, account $CLOUDSDK_CORE_ACCOUNT}"
  else
    case "$(apigee_edge_auth_mode)" in
      basic) printf 'Authorization: Basic <redacted> (user %s)\n' "${APIGEE_EDGE_USER:-<unset>}" ;;
      oauth) printf 'Authorization: Bearer <redacted> (Edge OAuth2, user %s)\n' "${APIGEE_EDGE_USER:-<unset>}" ;;
      token) printf 'Authorization: Bearer <redacted> (APIGEE_TOKEN)\n' ;;
    esac
  fi
}

apigee_edge_password() {
  [[ -n "${APIGEE_EDGE_USER:-}" ]] || apigee_die "APIGEE_EDGE_USER is not set"
  apigee_secret APIGEE_EDGE_PASSWORD \
    "${APIGEE_EDGE_KEYCHAIN_SERVICE:-$APIGEE_EDGE_KEYCHAIN_SERVICE_DEFAULT}" "$APIGEE_EDGE_USER" ||
    apigee_die "no Edge password: set APIGEE_EDGE_PASSWORD or store it in the Keychain:
  security add-generic-password -U -s '${APIGEE_EDGE_KEYCHAIN_SERVICE:-$APIGEE_EDGE_KEYCHAIN_SERVICE_DEFAULT}' -a '$APIGEE_EDGE_USER' -w"
}

apigee_edge_token_cache_file() {
  local key
  key="$(printf '%s' "${APIGEE_EDGE_USER:-anon}@${APIGEE_EDGE_TOKEN_URL:-$APIGEE_EDGE_TOKEN_URL_DEFAULT}" | tr -c 'A-Za-z0-9._@-' '_')"
  printf '%s/edge-token-%s\n' "$(apigee_cache_home)" "$key"
}

# Fetch an Edge OAuth2 access token (password or passcode grant). The client
# credentials, user password and passcode are written to a 0600 curl config
# file, never passed on the command line.
apigee_edge_oauth_token() {
  local cache now expiry token cfg out status client resp memo
  memo="$(apigee_tmpdir)/edge-token"
  if [[ -s "$memo" ]]; then
    cat "$memo"
    return 0
  fi
  cache="$(apigee_edge_token_cache_file)"
  now="$(date +%s)"
  if [[ "${APIGEE_NO_TOKEN_CACHE:-0}" != 1 && -s "$cache" ]]; then
    expiry="$(head -n 1 "$cache")"
    if [[ "$expiry" =~ ^[0-9]+$ ]] && ((expiry > now + 60)); then
      sed -n '2p' "$cache"
      return 0
    fi
  fi
  client="$(apigee_secret APIGEE_EDGE_SSO_CLIENT \
    "${APIGEE_EDGE_SSO_KEYCHAIN_SERVICE:-$APIGEE_EDGE_SSO_KEYCHAIN_SERVICE_DEFAULT}" client)" ||
    apigee_die "no Edge SSO client credentials: set APIGEE_EDGE_SSO_CLIENT='<client_id>:<client_secret>' (the public
  values documented for Apigee's get_token utility) or store them in the Keychain:
  security add-generic-password -U -s '${APIGEE_EDGE_SSO_KEYCHAIN_SERVICE:-$APIGEE_EDGE_SSO_KEYCHAIN_SERVICE_DEFAULT}' -a client -w"
  cfg="$(apigee_mktemp tokencfg)"
  out="$(apigee_mktemp tokenout)"
  local password=""
  if [[ -z "${APIGEE_EDGE_PASSCODE:-}" ]]; then
    [[ -n "${APIGEE_EDGE_USER:-}" ]] || apigee_die "APIGEE_EDGE_USER is not set"
    password="$(apigee_edge_password)" || exit 1
  fi
  {
    printf 'user = %s\n' "$(apigee_curl_cfg_quote "$client")"
    printf 'header = "Accept: application/json"\n'
    printf 'data-urlencode = "grant_type=password"\n'
    if [[ -n "${APIGEE_EDGE_PASSCODE:-}" ]]; then
      printf 'data-urlencode = %s\n' "$(apigee_curl_cfg_quote "passcode=$APIGEE_EDGE_PASSCODE")"
      printf 'data-urlencode = "response_type=token"\n'
    else
      printf 'data-urlencode = %s\n' "$(apigee_curl_cfg_quote "username=$APIGEE_EDGE_USER")"
      printf 'data-urlencode = %s\n' "$(apigee_curl_cfg_quote "password=$password")"
    fi
  } >"$cfg"
  password=""
  local url="${APIGEE_EDGE_TOKEN_URL:-$APIGEE_EDGE_TOKEN_URL_DEFAULT}"
  if [[ -n "${APIGEE_EDGE_MFA_CODE:-}" ]]; then
    url="$url?mfa_token=$(apigee_urlencode "$APIGEE_EDGE_MFA_CODE")"
  fi
  status="$(curl -sS --fail -X POST -o "$out" -w '%{http_code}' --config "$cfg" \
    -H 'Content-Type: application/x-www-form-urlencoded' "$url")" ||
    apigee_die "Edge token request failed (HTTP ${status:-n/a}) at $url"
  rm -f "$cfg"
  token="$(apigee_json get access_token <"$out")"
  [[ -n "$token" ]] || apigee_die "Edge token endpoint returned no access_token"
  resp="$(apigee_json get expires_in <"$out")"
  rm -f "$out"
  if [[ "${APIGEE_NO_TOKEN_CACHE:-0}" != 1 ]]; then
    (
      umask 077
      mkdir -p "$(dirname "$cache")"
      printf '%s\n%s\n' "$((now + ${resp:-1799}))" "$token" >"$cache"
    )
  fi
  (umask 077 && printf '%s\n' "$token" >"$memo")
  printf '%s\n' "$token"
}

# Print a bearer token for the selected platform (stdout only).
apigee_token() {
  if [[ -n "${APIGEE_TOKEN:-}" ]]; then
    printf '%s\n' "$APIGEE_TOKEN"
    return 0
  fi
  if [[ "$APIGEE_KIND" == x ]]; then
    local memo tok
    memo="$(apigee_tmpdir)/x-token"
    if [[ -s "$memo" ]]; then
      cat "$memo"
      return 0
    fi
    apigee_have gcloud || apigee_die "gcloud not found; install the Google Cloud SDK (setup/install.sh) or set APIGEE_TOKEN"
    tok="$(gcloud auth print-access-token 2>/dev/null)" ||
      apigee_die "gcloud auth print-access-token failed; run 'gcloud auth login'${CLOUDSDK_CORE_ACCOUNT:+ for $CLOUDSDK_CORE_ACCOUNT}"
    [[ -n "$tok" ]] || apigee_die "gcloud returned an empty token"
    (umask 077 && printf '%s\n' "$tok" >"$memo")
    printf '%s\n' "$tok"
    return 0
  fi
  case "$(apigee_edge_auth_mode)" in
    oauth) apigee_edge_oauth_token ;;
    basic) apigee_die "Edge basic auth has no bearer token; set APIGEE_EDGE_AUTH=oauth" ;;
    token) apigee_die "APIGEE_EDGE_AUTH=token requires APIGEE_TOKEN" ;;
  esac
}

# Write the curl config file that carries credentials for one request.
apigee_write_auth_config() {
  local cfg="$1" tok pass
  if [[ "$APIGEE_KIND" == edge && -z "${APIGEE_TOKEN:-}" && "$(apigee_edge_auth_mode)" == basic ]]; then
    pass="$(apigee_edge_password)" || exit 1
    printf 'user = %s\n' "$(apigee_curl_cfg_quote "$APIGEE_EDGE_USER:$pass")" >"$cfg"
  else
    tok="$(apigee_token)" || exit 1
    printf 'header = %s\n' "$(apigee_curl_cfg_quote "Authorization: Bearer $tok")" >"$cfg"
  fi
}

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------

# apigee_confirm "message" — required before any mutating request.
apigee_confirm() {
  local msg="$1" answer
  if [[ "$APIGEE_YES" == 1 || "$APIGEE_DRY_RUN" == 1 ]]; then
    return 0
  fi
  if [[ -t 0 ]]; then
    printf '%s [%s %s/%s] Proceed? [y/N] ' "$msg" "$(apigee_platform_label)" "${APIGEE_ORG:-?}" "${APIGEE_ENV:--}" >&2
    read -r answer || answer=""
    case "$answer" in
      y | Y | yes | YES) return 0 ;;
    esac
    apigee_die "aborted"
  fi
  apigee_die "refusing to run without confirmation: $msg (re-run with --yes)"
}

# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------

apigee_curl_fail_flag() {
  if [[ -z "${APIGEE_CURL_FAIL_FLAG:-}" ]]; then
    if curl --fail-with-body --version >/dev/null 2>&1; then
      APIGEE_CURL_FAIL_FLAG=--fail-with-body
    else
      APIGEE_CURL_FAIL_FLAG=--fail
    fi
  fi
  printf '%s\n' "$APIGEE_CURL_FAIL_FLAG"
}

# apigee_request METHOD PATH_OR_URL [options]
#   --json BODY          JSON request body (string)
#   --data-file FILE     request body from FILE (default content type JSON)
#   --form FIELD=@FILE   multipart/form-data upload
#   --content-type CT    override Content-Type
#   --accept TYPE        Accept header (default application/json)
#   --output FILE        write the response body to FILE
#   --ok CODES           comma-separated non-2xx codes to treat as success
#   --no-auth            do not send management credentials
#   --reader-auth        send a bearer token (for custom reader proxies)
# The HTTP status of the last request is stored in "$APIGEE_TMPDIR/status".
# Mutating methods are printed instead of sent when APIGEE_DRY_RUN=1.
apigee_request() {
  local method="$1" target="$2"
  shift 2
  local body="" body_file="" form="" ctype="" accept="application/json" output="" ok="" auth=mgmt
  while (($#)); do
    case "$1" in
      --json) body="$2"; shift 2 ;;
      --data-file) body_file="$2"; shift 2 ;;
      --form) form="$2"; shift 2 ;;
      --content-type) ctype="$2"; shift 2 ;;
      --accept) accept="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --ok) ok="$2"; shift 2 ;;
      --no-auth) auth=none; shift ;;
      --reader-auth) auth=bearer; shift ;;
      *) apigee_die "apigee_request: unknown option $1" ;;
    esac
  done
  local url="$target"
  [[ "$url" == http://* || "$url" == https://* ]] || url="$APIGEE_BASE_URL$target"
  if [[ -n "$body" && -z "$body_file" ]]; then
    body_file="$(apigee_mktemp body)"
    printf '%s' "$body" >"$body_file"
  fi
  if [[ -z "$ctype" && -n "$body_file" ]]; then
    ctype="application/json"
  fi

  local tmp status_file
  tmp="$(apigee_tmpdir)"
  status_file="$tmp/status"

  if [[ "$APIGEE_DRY_RUN" == 1 && "$method" != GET ]]; then
    {
      printf 'DRY-RUN: %s %s\n' "$method" "$url"
      if [[ "$auth" == mgmt ]]; then
        printf 'DRY-RUN:   %s\n' "$(apigee_auth_description)"
      fi
      if [[ -n "$ctype" ]]; then printf 'DRY-RUN:   Content-Type: %s\n' "$ctype"; fi
      if [[ -n "$body_file" ]]; then printf 'DRY-RUN:   body: %s bytes\n' "$(wc -c <"$body_file" | tr -d ' ')"; fi
      if [[ -n "$form" ]]; then printf 'DRY-RUN:   form: %s\n' "$form"; fi
    } | apigee_user_out
    printf '000' >"$status_file"
    return 0
  fi

  local args=(-sS "$(apigee_curl_fail_flag)" -X "$method" -w '%{http_code}' -H "Accept: $accept")
  local out_file="${output:-$(apigee_mktemp resp)}"
  args+=(-o "$out_file")
  if [[ "$auth" != none ]]; then
    local cfg
    cfg="$(apigee_mktemp auth)"
    if [[ "$auth" == mgmt ]]; then
      apigee_write_auth_config "$cfg"
    else
      local reader_tok
      reader_tok="$(apigee_token)" || exit 1
      printf 'header = %s\n' "$(apigee_curl_cfg_quote "Authorization: Bearer $reader_tok")" >"$cfg"
    fi
    args+=(--config "$cfg")
  fi
  if [[ -n "$form" ]]; then
    args+=(-F "$form")
  elif [[ -n "$body_file" ]]; then
    args+=(-H "Content-Type: $ctype" --data-binary "@$body_file")
  elif [[ "$method" == POST || "$method" == PUT ]]; then
    args+=(-H "Content-Type: ${ctype:-application/octet-stream}" --data-binary "")
  fi

  apigee_debug "$method $url"
  local code rc=0
  code="$(curl "${args[@]}" "$url")" || rc=$?
  [[ -n "${cfg:-}" ]] && rm -f "$cfg"
  printf '%s' "$code" >"$status_file"

  local accepted=0
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
    accepted=1
  elif [[ -n "$ok" && ",$ok," == *",$code,"* ]]; then
    accepted=1
  fi
  if ((accepted)); then
    if [[ -z "$output" ]]; then
      cat "$out_file"
      rm -f "$out_file"
    fi
    return 0
  fi
  if [[ "$rc" != 0 && "$rc" != 22 ]]; then
    apigee_warn "curl failed (exit $rc) for $method $url"
  else
    local detail=""
    if [[ -s "$out_file" ]]; then
      detail="$(head -c 600 "$out_file" | tr '\n' ' ')"
    fi
    apigee_warn "HTTP $code from $method $url${detail:+: $detail}"
  fi
  [[ -z "$output" ]] && rm -f "$out_file"
  return 1
}

apigee_last_status() {
  cat "$(apigee_tmpdir)/status" 2>/dev/null
}

apigee_get() {
  apigee_request GET "$@"
}
