#!/usr/bin/env bash
# gcloud-login.sh - reset and verify the gcloud login used by the Apigee toolkit.
#
# Use it when gcloud hands out a token for the wrong Google account (symptoms:
# 403s from the Apigee API, or "gcloud gave a token for 'X', but
# CLOUDSDK_CORE_ACCOUNT is 'Y'"). The usual cause is a stored credential that
# was saved under one account name but belongs to another, typically after a
# browser login with several Google accounts signed in.
#
# What it does:
#   1. revokes the stored credential for ACCOUNT (other accounts are untouched)
#   2. deletes gcloud's access-token cache
#   3. prints the login URL (gcloud auth login --no-launch-browser); open it in
#      a PRIVATE/INCOGNITO window and sign in as ACCOUNT only
#   4. after you finish in the browser, checks that
#        - the token requested with --account=ACCOUNT is really ACCOUNT's
#        - the token gcloud gives by default is ACCOUNT's
#        - the stored credential and the cache hold ACCOUNT
#
# Usage: gcloud-login.sh [ACCOUNT]       (default: $CLOUDSDK_CORE_ACCOUNT)
#        gcloud-login.sh --check [ACCOUNT]   run only the checks (step 4)
# Exit status: 0 all checks passed, 1 a check failed, 2 usage/setup problem.
set -u

only_check=0
if [[ "${1:-}" == "--check" ]]; then only_check=1; shift; fi
case "${1:-}" in -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

account="${1:-${CLOUDSDK_CORE_ACCOUNT:-}}"
if [[ -z "$account" ]]; then
  echo "usage: ${0##*/} [--check] ACCOUNT   (or set CLOUDSDK_CORE_ACCOUNT)" >&2
  exit 2
fi
command -v gcloud >/dev/null || { echo "gcloud not found" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl not found" >&2; exit 2; }

cfg="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"
fail=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=1; }

if [[ $only_check -eq 0 ]]; then
  echo "== Resetting gcloud login for $account"
  # Never export CLOUDSDK_CORE_ACCOUNT into these calls; they must act on ACCOUNT explicitly.
  gcloud auth revoke "$account" >/dev/null 2>&1 \
    && echo "  revoked stored credential" \
    || echo "  (no stored credential to revoke)"
  rm -f "$cfg/access_tokens.db" && echo "  cleared token cache"
  echo
  echo "== Log in"
  echo "gcloud prints a URL below. Copy it into a PRIVATE/INCOGNITO window and sign in"
  echo "as $account only (no other Google account in that window)."
  echo
  if ! gcloud auth login "$account" --no-launch-browser; then
    echo "login did not complete" >&2
    exit 1
  fi
  echo
fi

echo "== Checks for $account"

# json_field FIELD: read one string/number field from a flat JSON object on stdin.
json_field() {
  python3 -c 'import sys,json
try: print(json.load(sys.stdin).get(sys.argv[1],""))
except Exception: print("")' "$1"
}

tokeninfo() { curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$1"; }

# 1. Token requested for the account by name.
tok="$(gcloud auth print-access-token --account="$account" 2>/dev/null)"
if [[ -z "$tok" ]]; then
  bad "gcloud gave no token for --account=$account"
else
  info="$(tokeninfo "$tok")"
  got="$(printf '%s' "$info" | json_field email)"
  exp="$(printf '%s' "$info" | json_field expires_in)"
  if [[ "$got" == "$account" ]]; then
    ok "--account=$account gives a token for $got (expires in ${exp:-?}s)"
  else
    bad "--account=$account gives a token for '${got:-unknown}'"
  fi
fi

# 2. Token gcloud gives by default (what the toolkit uses).
tok="$(CLOUDSDK_CORE_ACCOUNT="$account" gcloud auth print-access-token 2>/dev/null)"
if [[ -z "$tok" ]]; then
  bad "default token request returned nothing"
else
  got="$(tokeninfo "$tok" | json_field email)"
  if [[ "$got" == "$account" ]]; then
    ok "default token is for $got"
  else
    bad "default token is for '${got:-unknown}'"
  fi
fi

# 3. Stored credential and cache (informational; needs sqlite3).
if command -v sqlite3 >/dev/null && [[ -f "$cfg/credentials.db" ]]; then
  n="$(sqlite3 "$cfg/credentials.db" "select count(*) from credentials where account_id='$account';" 2>/dev/null)"
  [[ "${n:-0}" == 1 ]] && ok "credentials.db holds one entry for $account" \
                       || bad "credentials.db has ${n:-0} entries for $account"
fi

# 4. Account selection.
active="$(gcloud config get-value account 2>/dev/null)"
if [[ "$active" == "$account" ]]; then ok "active gcloud account is $active"
else echo "  note  active gcloud account is '${active:-none}' (CLOUDSDK_CORE_ACCOUNT overrides it)"; fi
if [[ -n "${CLOUDSDK_CORE_ACCOUNT:-}" && "$CLOUDSDK_CORE_ACCOUNT" != "$account" ]]; then
  bad "CLOUDSDK_CORE_ACCOUNT is '$CLOUDSDK_CORE_ACCOUNT' in this shell"
fi

echo
if [[ $fail -eq 0 ]]; then
  echo "All checks passed. Re-run your apigee command."
  exit 0
fi
cat <<EOF
One or more checks failed. If the token belongs to another account, the browser
session you signed in with was not $account. Run this again and use a fresh
private window with only $account signed in.
EOF
exit 1
