#!/usr/bin/env bash
# gcloud-sa-key.sh - authenticate the toolkit with a service-account key, so it
# never needs a browser login again.
#
# A user login (refresh token) can be revoked or expire; a service-account key
# does not. After this script runs, bin/apigee and tools/compare_envs.py use the
# key automatically (gcloud signs in from the file for those calls only; your
# own gcloud login is not touched).
#
# Usage: gcloud-sa-key.sh [options]
#   --project ID     project of the service account (default: gcloud's project)
#   --sa NAME        service account name (default: apigee-toolkit; made by gcloud-impersonate.sh)
#   --key-file FILE  where to save the key (default: <config home>/sa-key.json, mode 600)
#   --force          replace an existing key file
#   --check          only verify that the saved key yields a token
#   --remove         delete the local key file and the service account's keys
#   -y, --yes        do not ask before creating
#   -n, --dry-run    print the commands and change nothing
#   -h, --help
#
# You need a working gcloud login ONCE, with permission to create keys on the
# service account (Service Account Key Admin). If your organization enforces
# constraints/iam.disableServiceAccountKeyCreation, key creation is refused and
# an organization admin must allow it for this project.
#
# The key is a secret: it is saved outside the repository with mode 600 and is
# never printed. Delete it with --remove when you no longer need it.
set -u

project="" sa_name="apigee-toolkit" keyfile="" force=0 check=0 remove=0 yes=0 dry=0
while (($#)); do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --sa) sa_name="$2"; shift 2 ;;
    --key-file) keyfile="$2"; shift 2 ;;
    --force) force=1; shift ;;
    --check) check=1; shift ;;
    --remove) remove=1; shift ;;
    -y | --yes) yes=1; shift ;;
    -n | --dry-run) dry=1; shift ;;
    -h | --help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v gcloud >/dev/null || { echo "gcloud not found" >&2; exit 2; }
cfg="${APIGEE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/apigee-toolkit}"
[[ -n "$keyfile" ]] || keyfile="$cfg/sa-key.json"
[[ -n "$project" ]] || project="$(gcloud config get-value project 2>/dev/null)"
[[ -n "$project" && "$project" != "(unset)" ]] || { echo "no project: pass --project ID" >&2; exit 2; }
sa="$sa_name@$project.iam.gserviceaccount.com"

show() { printf '+'; printf ' %q' "$@"; printf '\n'; }

verify() {
  # A new key can take several seconds to become usable, so retry. The person's
  # CLOUDSDK_CORE_ACCOUNT must not apply: the key IS the account here.
  local tok i err="$cfg/.sa-key-verify.err"
  mkdir -p "$cfg"
  for ((i = 1; i <= ${GCLOUD_KEY_TRIES:-6}; i++)); do
    tok="$(env -u CLOUDSDK_CORE_ACCOUNT CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$keyfile" gcloud auth print-access-token 2>"$err")"
    if [[ -n "$tok" ]]; then rm -f "$err"; echo "  token ok: $keyfile yields an access token for $sa"; return 0; fi
    sleep "${GCLOUD_KEY_WAIT:-5}"
  done
  echo "  FAIL: no token from $keyfile" >&2
  sed 's/^/  gcloud said: /' "$err" >&2
  rm -f "$err"
  return 1
}

if ((check)); then
  [[ -s "$keyfile" ]] || { echo "no key at $keyfile" >&2; exit 1; }
  verify; exit $?
fi

if ((remove)); then
  echo "Removing the local key and the keys of $sa"
  if ((dry)); then show rm -f "$keyfile"; show gcloud iam service-accounts keys list --iam-account="$sa" --managed-by=user; exit 0; fi
  rm -f "$keyfile"
  while read -r id; do
    [[ -n "$id" ]] || continue
    gcloud iam service-accounts keys delete "$id" --iam-account="$sa" --quiet
  done < <(gcloud iam service-accounts keys list --iam-account="$sa" --managed-by=user --format='value(name.basename())' 2>/dev/null)
  exit 0
fi

echo "Service account: $sa"
echo "Key file:        $keyfile"
if [[ -e "$keyfile" && $force -eq 0 ]]; then
  echo "a key file already exists at $keyfile (use --force to replace it, or --check to test it)" >&2
  exit 1
fi
if ((dry)); then
  show mkdir -p "$(dirname "$keyfile")"
  show gcloud iam service-accounts keys create "$keyfile" --iam-account="$sa"
  show chmod 600 "$keyfile"
  exit 0
fi
if ((!yes)); then
  [[ -t 0 ]] || { echo "needs confirmation: re-run with --yes" >&2; exit 1; }
  read -r -p "Create a key for $sa and save it to $keyfile? [y/N] " ans
  [[ "$ans" == y || "$ans" == Y ]] || exit 1
fi

mkdir -p "$(dirname "$keyfile")"
tmp="$keyfile.new"
rm -f "$tmp"
(umask 077; gcloud iam service-accounts keys create "$tmp" --iam-account="$sa" 2>"$tmp.err")
rc=$?
if ((rc != 0)) || [[ ! -s "$tmp" ]]; then
  rm -f "$tmp"
  echo "Key creation failed:" >&2
  sed 's/^/  /' "$tmp.err" >&2
  if grep -q disableServiceAccountKeyCreation "$tmp.err"; then
    echo "Your organization blocks service-account keys (constraints/iam.disableServiceAccountKeyCreation)." >&2
    echo "An organization admin can allow it for project $project, or use a different login method." >&2
  fi
  rm -f "$tmp.err"
  exit 1
fi
rm -f "$tmp.err"
chmod 600 "$tmp"
mv -f "$tmp" "$keyfile"
echo "Saved the key (mode 600)."
verify
