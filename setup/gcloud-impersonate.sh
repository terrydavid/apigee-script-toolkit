#!/usr/bin/env bash
# gcloud-impersonate.sh - set up service-account impersonation for the toolkit.
#
# Why: a login token is tied to one browser sign-in and can be saved under the
# wrong account. With impersonation, gcloud mints a fresh short-lived token for
# a dedicated service account on every call, using your login only to ask for
# it. No hourly re-login, no 403s from a stale token, and the identity is the
# service account every time. (Each token still lasts 1 hour; gcloud simply
# gets a new one when needed. A longer lifetime needs an organization policy.)
#
# Usage: gcloud-impersonate.sh [options]
#   --project ID        project that holds the Apigee org (default: $APIGEE_ORG or gcloud's project)
#   --sa NAME           service account name        (default: apigee-toolkit)
#   --user ACCOUNT      person who may impersonate  (default: $CLOUDSDK_CORE_ACCOUNT)
#   --read-only         grant roles/apigee.readOnlyAdmin instead of roles/apigee.admin
#   --role ROLE         grant this role instead (repeatable)
#   --no-config         do not change gcloud's configuration (print the command instead)
#   -y, --yes           do not ask before making changes
#   -n, --dry-run       print the commands and change nothing
#   --undo              stop impersonating (gcloud config unset); leaves the service account
#   -h, --help
#
# What it changes (all idempotent):
#   1. enables the IAM Service Account Credentials API on the project
#   2. creates the service account (if missing)
#   3. grants the service account its Apigee role(s) on the project
#   4. grants --user roles/iam.serviceAccountTokenCreator on that service account only
#   5. verifies that a token really belongs to the service account (retries while
#      IAM propagates, up to about 3 minutes)
#   6. only then sets auth/impersonate_service_account in the ACTIVE gcloud
#      configuration; if the check fails, gcloud is left unchanged
#
# You need permission to create service accounts and edit the project's IAM
# policy (for example Owner, or Service Account Admin + Project IAM Admin).
set -u

project="" sa_name="apigee-toolkit" user="${CLOUDSDK_CORE_ACCOUNT:-}"
roles=() readonly_roles=0 do_config=1 yes=0 dry=0 undo=0
while (($#)); do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --sa) sa_name="$2"; shift 2 ;;
    --user) user="$2"; shift 2 ;;
    --read-only) readonly_roles=1; shift ;;
    --role) roles+=("$2"); shift 2 ;;
    --no-config) do_config=0; shift ;;
    -y|--yes) yes=1; shift ;;
    -n|--dry-run) dry=1; shift ;;
    --undo) undo=1; shift ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v gcloud >/dev/null || { echo "gcloud not found" >&2; exit 2; }

if [[ $undo -eq 1 ]]; then
  echo "Stopping impersonation in the active gcloud configuration"
  if [[ $dry -eq 1 ]]; then echo "+ gcloud config unset auth/impersonate_service_account"; exit 0; fi
  gcloud config unset auth/impersonate_service_account
  exit $?
fi

gq() { gcloud "$@"; }

[[ -n "$project" ]] || project="$(gq config get-value project 2>/dev/null)"
[[ -n "$project" && "$project" != "(unset)" ]] || { echo "no project: pass --project ID" >&2; exit 2; }
[[ -n "$user" ]] || { echo "no user: pass --user ACCOUNT (or set CLOUDSDK_CORE_ACCOUNT)" >&2; exit 2; }
if ((${#roles[@]} == 0)); then
  if [[ $readonly_roles -eq 1 ]]; then roles=(roles/apigee.readOnlyAdmin); else roles=(roles/apigee.admin); fi
fi
sa="$sa_name@$project.iam.gserviceaccount.com"

echo "Project:          $project"
echo "Service account:  $sa"
echo "Impersonated by:  $user"
echo "Apigee role(s):   ${roles[*]}"
echo "gcloud config:    $([[ $do_config -eq 1 ]] && echo "set auth/impersonate_service_account in the active configuration" || echo "unchanged")"
echo

if [[ $dry -eq 0 && $yes -eq 0 ]]; then
  read -r -p "Make these changes? [y/N] " a
  [[ "$a" == [yY]* ]] || { echo "cancelled"; exit 1; }
fi

# The setup calls must run as YOU. If impersonation is already on (a re-run),
# switch it off first; step 5 turns it back on.
if [[ -n "${CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT:-}" ]]; then
  echo "CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT is set in this shell; unset it and run again." >&2
  exit 2
fi
if [[ $dry -eq 0 && -n "$(gcloud config get-value auth/impersonate_service_account 2>/dev/null)" ]]; then
  gcloud config unset auth/impersonate_service_account >/dev/null 2>&1
fi
step_fail=0
run() {
  echo "+ $(printf '%q ' "$@")"
  [[ $dry -eq 1 ]] && return 0
  "$@" || { echo "  command failed (status $?)" >&2; step_fail=1; return 1; }
}

echo "== 1/6 enable IAM Service Account Credentials API"
run gcloud services enable iamcredentials.googleapis.com --project "$project"

echo "== 2/6 service account"
if [[ $dry -eq 0 ]] && gq iam service-accounts describe "$sa" --project "$project" >/dev/null 2>&1; then
  echo "  $sa already exists"
else
  run gcloud iam service-accounts create "$sa_name" \
    --project "$project" --display-name "Apigee toolkit"
fi

echo "== 3/6 Apigee role(s) for the service account"
for r in "${roles[@]}"; do
  run gcloud projects add-iam-policy-binding "$project" \
    --member "serviceAccount:$sa" --role "$r" --condition=None --quiet --format=none
done

echo "== 4/6 let $user create tokens for it"
run gcloud iam service-accounts add-iam-policy-binding "$sa" \
  --project "$project" --member "user:$user" --role roles/iam.serviceAccountTokenCreator --quiet --format=none

echo "== 5/6 verify (gcloud is not switched to impersonation until this passes)"
if [[ $dry -eq 1 ]]; then
  echo "  (dry run: not verified)"
  echo "== 6/6 gcloud configuration"
  if [[ $do_config -eq 1 ]]; then
    echo "+ gcloud config set auth/impersonate_service_account $sa"
  else
    echo "  skipped (--no-config)"
  fi
  exit 0
fi
if [[ $step_fail -ne 0 ]]; then
  echo "Some steps failed; fix the errors above and run again (the script is safe to repeat)." >&2
  exit 1
fi
errf="$(mktemp)"
ok=0
tries=12
for ((i = 1; i <= tries; i++)); do
  tok="$(gcloud auth print-access-token --impersonate-service-account="$sa" 2>"$errf")"
  if [[ -n "$tok" ]]; then
    got="$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$tok" \
      | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("email",""))
except Exception: print("")')"
    if [[ "$got" == "$sa" ]]; then ok=1; break; fi
    echo "  token is for '${got:-unknown}', expected $sa"; break
  fi
  echo "  waiting for the IAM change to propagate (try $i of $tries)..."
  sleep "${GCLOUD_IMPERSONATE_WAIT:-15}"
done
if [[ $ok -ne 1 ]]; then
  echo "  FAIL  could not get a token for $sa:" >&2
  grep -v '^WARNING' "$errf" | head -8 | sed 's/^/        /' >&2
  rm -f "$errf"
  cat >&2 <<EOT

gcloud was NOT switched to impersonation (your configuration is unchanged).
Everything created above is kept; run this script again to retry only the check.
If it keeps failing after a few minutes, look at the service account's policy:
  gcloud iam service-accounts get-iam-policy $sa --project $project
and at organization-level restrictions (deny policies, Principal Access
Boundaries) on iam.serviceAccounts.getAccessToken.
EOT
  exit 1
fi
rm -f "$errf"
echo "  ok    token belongs to $sa"

echo "== 6/6 gcloud configuration"
if [[ $do_config -eq 1 ]]; then
  run gcloud config set auth/impersonate_service_account "$sa" || exit 1
  echo
  echo "Done. gcloud now uses $sa for every command in this configuration."
else
  echo "  skipped. To switch on later:  gcloud config set auth/impersonate_service_account $sa"
  echo "  or per shell:                 export CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=$sa"
fi
echo "Check:  bin/apigee --org $project --platform x org get"
echo "Undo:   $0 --undo"
exit 0
