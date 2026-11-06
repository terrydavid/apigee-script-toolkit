#!/usr/bin/env bash
#
# Check for (and, with your consent, install via Homebrew) the tools used by
# apigee-toolkit. Safe to re-run: anything already present is left alone.
#
#   setup/install.sh            interactive: offer to install what is missing
#   setup/install.sh --check    report only; exit 1 if a required tool is missing
#   setup/install.sh --yes      install missing tools without prompting
#   setup/install.sh --optional also offer optional tools (apigeelint, node-jose)
#
set -euo pipefail

MODE=install
ASSUME_YES=0
OPTIONAL=0
for arg in "$@"; do
  case "$arg" in
    --check) MODE=check ;;
    --yes | -y) ASSUME_YES=1 ;;
    --optional) OPTIONAL=1 ;;
    -h | --help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'install.sh: unknown option %s\n' "$arg" >&2; exit 2 ;;
  esac
done

HOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
missing_required=0

have() { command -v "$1" >/dev/null 2>&1; }

ask() {
  [[ "$ASSUME_YES" == 1 ]] && return 0
  [[ -t 0 ]] || return 1
  local answer
  printf '%s [y/N] ' "$1" >&2
  read -r answer || return 1
  [[ "$answer" == y || "$answer" == Y || "$answer" == yes ]]
}

status() { printf '  %-12s %-9s %s\n' "$1" "$2" "${3:-}"; }

# offer NAME CHECK_CMD INSTALL_CMD REQUIRED(1/0) PURPOSE
offer() {
  local name="$1" check="$2" install="$3" required="$4" purpose="$5"
  if eval "$check" >/dev/null 2>&1; then
    status "$name" ok "$purpose"
    return 0
  fi
  status "$name" missing "$purpose"
  if [[ "$MODE" == check ]]; then
    [[ "$required" == 1 ]] && missing_required=1
    return 0
  fi
  if [[ -z "$install" ]]; then
    [[ "$required" == 1 ]] && missing_required=1
    return 0
  fi
  if ask "Install $name with: $install ?"; then
    eval "$install"
  else
    printf '    skipped; install manually with: %s\n' "$install" >&2
    [[ "$required" == 1 ]] && missing_required=1
  fi
  return 0
}

printf 'apigee-toolkit dependencies (%s mode)\n' "$MODE"

if ! have brew && [[ "$MODE" == install ]]; then
  printf '  Homebrew not found; automatic installs are unavailable (https://brew.sh)\n' >&2
fi
BREW=""
have brew && BREW=brew

offer bash 'bash --version' '' 1 "shell (macOS bash 3.2 is fine)"
offer curl 'curl --version' "${BREW:+brew install curl}" 1 "HTTP client"
offer jq 'jq --version' "${BREW:+brew install jq}" 0 "JSON (preferred; python3 is the fallback)"
offer python3 'python3 --version' "${BREW:+brew install python}" 0 "JSON fallback when jq is missing"
if ! have jq && ! have python3; then
  missing_required=1
  printf '  -> one of jq or python3 is required\n' >&2
fi
offer zip 'zip -v' "${BREW:+brew install zip}" 0 "proxy/sharedflow import from a directory"
offer unzip 'unzip -v' "${BREW:+brew install unzip}" 0 "proxy/sharedflow compare"
offer gcloud 'gcloud --version' "${BREW:+brew install --cask google-cloud-sdk}" 0 "Apigee X/hybrid auth and 'gcloud apigee'"
if have gcloud; then
  if gcloud apigee --help >/dev/null 2>&1; then
    status "gcloud apigee" ok "command group available"
  else
    status "gcloud apigee" missing "run: gcloud components update"
  fi
fi
offer security 'command -v security' '' 0 "macOS Keychain (Edge credentials)"

if [[ "$OPTIONAL" == 1 || "$MODE" == check ]]; then
  offer apigeelint 'apigeelint --version' "$(have npm && printf 'npm install -g apigeelint')" 0 "optional: proxy bundle linter"
  offer apigeecli 'apigeecli --version' '' 0 "optional: see https://github.com/apigee/apigeecli#installation"
  offer node-jose "test -d '$HOME_DIR/tools/node_modules/node-jose'" \
    "$(have npm && printf "npm --prefix '%s/tools' install" "$HOME_DIR")" 0 "optional: tools/cvtPEM2JWK.js"
fi

if [[ "$missing_required" == 1 ]]; then
  printf '\nRequired tools are missing.\n' >&2
  exit 1
fi
printf '\nAll required tools are present. Next: cp config/apigee.env.example config/apigee.env && setup/doctor.sh\n'
