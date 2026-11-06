# shellcheck shell=bash
#
# apigee proxy|sharedflow <verb>  — API proxy and shared flow bundles.
# Both resources share one implementation; $1 of every function is the
# resource label ("proxy" or "sharedflow").

BUNDLE_VERBS="list revisions latest deployed download import deploy undeploy delete-revision clean-revisions compare"

# shellcheck disable=SC2086
proxy_verbs() { printf '%s\n' $BUNDLE_VERBS; }
# shellcheck disable=SC2086
sharedflow_verbs() { printf '%s\n' $BUNDLE_VERBS; }
proxy_help() { bundle_help proxy "${1:-}"; }
sharedflow_help() { bundle_help sharedflow "${1:-}"; }
proxy_main() { bundle_main proxy "$@"; }
sharedflow_main() { bundle_main sharedflow "$@"; }

bundle_collection() {
  if [[ "$1" == proxy ]]; then printf 'apis\n'; else printf 'sharedflows\n'; fi
}

bundle_dir_name() {
  if [[ "$1" == proxy ]]; then printf 'apiproxy\n'; else printf 'sharedflowbundle\n'; fi
}

bundle_help() {
  local label="$1" verb="${2:-}" noun nouns article
  if [[ "$label" == proxy ]]; then
    noun="API proxy" nouns="API proxies" article="an"
  else
    noun="shared flow" nouns="shared flows" article="a"
  fi
  case "$verb" in
    "")
      cat <<EOF
Usage: apigee $label <verb> [options]

Verbs:
  list                         List $nouns in the organization
  revisions NAME               List revisions of $article $noun
  latest NAME                  Print the newest revision number
  deployed NAME [--all-envs]   Print revision(s) deployed in --env (or every env)
  download NAME [REV]          Download a revision bundle (.zip)
  import NAME ZIP|DIR          Import a bundle as a new revision
  deploy NAME REV|--latest     Deploy a revision to --env
  undeploy NAME [REV]          Undeploy from --env (default: whatever is deployed)
  delete-revision NAME REV...  Delete revisions (ranges like 3-7 allowed)
  clean-revisions NAME...|--all  Delete old undeployed revisions (keeps newest N)
  compare NAME [A [B]]         Diff two revisions, or a revision and a local dir

Run 'apigee $label <verb> --help' for details.
EOF
      ;;
    list) printf 'Usage: apigee %s list\n\nList all %s in the organization, one per line.\n' "$label" "$nouns" ;;
    revisions) printf 'Usage: apigee %s revisions NAME\n\nList revision numbers of NAME in ascending order.\n' "$label" ;;
    latest) printf 'Usage: apigee %s latest NAME\n\nPrint the highest revision number of NAME.\n' "$label" ;;
    deployed)
      cat <<EOF
Usage: apigee $label deployed NAME [--all-envs]

Print revisions of NAME deployed in the current environment (--env), or
"environment revision" pairs for every environment with --all-envs.
EOF
      ;;
    download)
      cat <<EOF
Usage: apigee $label download NAME [REV] [--latest | --deployed] [-o FILE]

Download a revision bundle. Defaults to the latest revision; --deployed picks
the revision deployed in --env. Output defaults to ./NAME-revREV.zip.
EOF
      ;;
    import)
      cat <<EOF
Usage: apigee $label import NAME ZIP|DIR [--validate]

Import a bundle as a new revision. DIR may be a directory containing
$(bundle_dir_name "$label")/ or the $(bundle_dir_name "$label") directory itself (it is zipped for you).
Prints the new revision number. Mutating: asks for confirmation unless --yes.
EOF
      ;;
    deploy)
      cat <<EOF
Usage: apigee $label deploy NAME (REV | --latest) [--no-override] [--service-account EMAIL]

Deploy a revision to --env. By default override=true so the new revision
replaces the currently deployed one without downtime. --service-account is
Apigee X/hybrid only. Mutating: asks for confirmation unless --yes.
EOF
      ;;
    undeploy)
      cat <<EOF
Usage: apigee $label undeploy NAME [REV]

Undeploy REV (default: every revision deployed in --env).
Mutating: asks for confirmation unless --yes.
EOF
      ;;
    delete-revision)
      cat <<EOF
Usage: apigee $label delete-revision NAME REV [REV|A-B ...]

Delete one or more revisions. Ranges (3-7) are expanded. Revisions deployed
in any environment are skipped. Mutating: asks for confirmation unless --yes.
EOF
      ;;
    clean-revisions)
      cat <<EOF
Usage: apigee $label clean-revisions (NAME... | --all) [--keep N]

Delete revisions that are neither among the newest N (default 5) nor deployed
in any environment. Use --dry-run to preview. Mutating: asks for confirmation
unless --yes.
EOF
      ;;
    compare)
      cat <<EOF
Usage: apigee $label compare NAME [REV_A [REV_B]]
       apigee $label compare NAME [REV] --dir LOCAL_DIR

Recursive diff of two revisions (default: latest vs. the one deployed in
--env), or of a revision (default: deployed in --env, else latest) and a local
source directory. Exit status: 0 identical, 1 different.
EOF
      ;;
    *) apigee_die "unknown $label verb '$verb' (see 'apigee $label --help')" ;;
  esac
}

bundle_path() {
  local label="$1" name="$2"
  printf '%s/%s/%s\n' "$(apigee_org_path)" "$(bundle_collection "$label")" "$(apigee_urlencode "$name")"
}

bundle_env_path() {
  local label="$1" name="$2"
  printf '%s/%s/%s\n' "$(apigee_env_path)" "$(bundle_collection "$label")" "$(apigee_urlencode "$name")"
}

bundle_require_name() {
  [[ -n "${2:-}" ]] || apigee_die "missing NAME (see 'apigee $1 ${3:-} --help')"
  [[ "$2" != -* ]] || apigee_die "unknown option $2 (see 'apigee $1 ${3:-} --help')"
}

bundle_list() {
  local label="$1" body
  body="$(apigee_get "$(apigee_org_path)/$(bundle_collection "$label")")" || exit 1
  printf '%s' "$body" | apigee_json names | sort
}

bundle_revisions() {
  local label="$1" name="$2" body
  body="$(apigee_get "$(bundle_path "$label" "$name")/revisions")" || exit 1
  printf '%s' "$body" | apigee_json names | sort -n
}

bundle_latest() {
  local label="$1" name="$2" revs
  revs="$(bundle_revisions "$label" "$name")" || exit 1
  [[ -n "$revs" ]] || apigee_die "$label '$name' has no revisions"
  printf '%s\n' "$revs" | tail -n 1
}

bundle_deployed_env() {
  local label="$1" name="$2" body
  body="$(apigee_get "$(bundle_env_path "$label" "$name")/deployments" --ok 400,404)" || exit 1
  case "$(apigee_last_status)" in
    400 | 404) return 0 ;;
  esac
  printf '%s' "$body" | apigee_json deployed-revs | sort -n
}

bundle_deployed_all() {
  local label="$1" name="$2" body
  body="$(apigee_get "$(bundle_path "$label" "$name")/deployments" --ok 400,404)" || exit 1
  case "$(apigee_last_status)" in
    400 | 404) return 0 ;;
  esac
  printf '%s' "$body" | apigee_json deployed-all
}

bundle_deployed() {
  local label="$1" name="" all=false
  shift
  while (($#)); do
    case "$1" in
      --all-envs) all=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *)
        [[ -z "$name" ]] || apigee_die "unexpected argument '$1' (see 'apigee $label deployed --help')"
        name="$1"
        shift
        ;;
    esac
  done
  bundle_require_name "$label" "$name" deployed
  if [[ "$all" == true ]]; then
    bundle_deployed_all "$label" "$name"
  else
    bundle_deployed_env "$label" "$name"
  fi
}

# Expand "3 5-7 9..10" into one revision per line.
bundle_expand_revs() {
  local spec a b i
  for spec in "$@"; do
    if [[ "$spec" =~ ^([0-9]+)(-|\.\.)([0-9]+)$ ]]; then
      a="${BASH_REMATCH[1]}"
      b="${BASH_REMATCH[3]}"
      ((a <= b)) || apigee_die "bad revision range '$spec'"
      for ((i = a; i <= b; i++)); do printf '%s\n' "$i"; done
    elif [[ "$spec" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$spec"
    else
      apigee_die "bad revision '$spec'"
    fi
  done
}

bundle_download_to() {
  local label="$1" name="$2" rev="$3" out="$4"
  apigee_request GET "$(bundle_path "$label" "$name")/revisions/$rev?format=bundle" \
    --accept '*/*' --output "$out" || apigee_die "download of $label $name revision $rev failed"
}

bundle_download() {
  local label="$1" name="" rev="" mode=latest out=""
  shift
  while (($#)); do
    case "$1" in
      --latest) mode=latest; shift ;;
      --deployed) mode=deployed; shift ;;
      -o | --output) out="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) if [[ -z "$name" ]]; then name="$1"; else rev="$1"; fi; shift ;;
    esac
  done
  bundle_require_name "$label" "$name" download
  if [[ -z "$rev" ]]; then
    if [[ "$mode" == deployed ]]; then
      rev="$(bundle_deployed_env "$label" "$name" | tail -n 1)"
      [[ -n "$rev" ]] || apigee_die "$label '$name' is not deployed in $(apigee_env)"
    else
      rev="$(bundle_latest "$label" "$name")" || exit 1
    fi
  fi
  out="${out:-./$name-rev$rev.zip}"
  bundle_download_to "$label" "$name" "$rev" "$out"
  apigee_info "downloaded $label $name revision $rev to $out"
}

bundle_zip_dir() {
  local label="$1" dir="$2" zipfile="$3" sub
  sub="$(bundle_dir_name "$label")"
  apigee_have zip || apigee_die "zip is required to import a directory"
  if [[ -d "$dir/$sub" ]]; then
    (cd "$dir" && zip -qr "$zipfile" "$sub" -x '*.DS_Store')
  elif [[ "$(basename "$dir")" == "$sub" ]]; then
    (cd "$dir/.." && zip -qr "$zipfile" "$sub" -x '*.DS_Store')
  else
    apigee_die "$dir does not contain $sub/"
  fi
}

bundle_import() {
  local label="$1" name="" src="" validate=false
  shift
  while (($#)); do
    case "$1" in
      --validate) validate=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) if [[ -z "$name" ]]; then name="$1"; else src="$1"; fi; shift ;;
    esac
  done
  bundle_require_name "$label" "$name" import
  [[ -n "$src" ]] || apigee_die "missing ZIP or DIR"
  local zipfile="$src"
  if [[ -d "$src" ]]; then
    zipfile="$(apigee_tmpdir)/$name.zip"
    bundle_zip_dir "$label" "$src" "$zipfile"
  fi
  [[ -f "$zipfile" ]] || apigee_die "bundle not found: $src"
  apigee_confirm "Import $src as a new revision of $label '$name'."
  local query body
  query="action=import&name=$(apigee_urlencode "$name")"
  [[ "$validate" == true ]] && query="$query&validate=true"
  body="$(apigee_request POST "$(apigee_org_path)/$(bundle_collection "$label")?$query" --form "file=@$zipfile")" || exit 1
  if [[ -n "$body" ]]; then
    printf '%s' "$body" | apigee_json get revision
  fi
}

bundle_deploy() {
  local label="$1" name="" rev="" latest=false override=true sa=""
  shift
  while (($#)); do
    case "$1" in
      --latest) latest=true; shift ;;
      --no-override) override=false; shift ;;
      --override) override=true; shift ;;
      --service-account) sa="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) if [[ -z "$name" ]]; then name="$1"; else rev="$1"; fi; shift ;;
    esac
  done
  bundle_require_name "$label" "$name" deploy
  if [[ -z "$rev" ]]; then
    [[ "$latest" == true ]] || apigee_die "specify a revision or --latest"
    rev="$(bundle_latest "$label" "$name")" || exit 1
  fi
  [[ "$rev" =~ ^[0-9]+$ ]] || apigee_die "bad revision '$rev'"
  local query="override=$override"
  if [[ -n "$sa" ]]; then
    apigee_require_platform x "--service-account"
    query="$query&serviceAccount=$(apigee_urlencode "$sa")"
  fi
  apigee_confirm "Deploy $label '$name' revision $rev to environment '$(apigee_env)'."
  local body
  body="$(apigee_request POST "$(bundle_env_path "$label" "$name")/revisions/$rev/deployments?$query" \
    --content-type application/x-www-form-urlencoded)" || exit 1
  if [[ -n "$body" ]]; then
    printf '%s' "$body" | apigee_json pretty
  fi
}

bundle_undeploy() {
  local label="$1" name="${2:-}" rev="${3:-}" revs r
  bundle_require_name "$label" "$name" undeploy
  if [[ -n "$rev" ]]; then
    revs="$rev"
  else
    revs="$(bundle_deployed_env "$label" "$name")" || exit 1
    if [[ -z "$revs" ]]; then
      apigee_info "$label '$name' is not deployed in $(apigee_env)"
      return 0
    fi
  fi
  apigee_confirm "Undeploy $label '$name' revision(s) $(printf '%s' "$revs" | tr '\n' ' ' | sed 's/ *$//') from '$(apigee_env)'."
  for r in $revs; do
    apigee_request DELETE "$(bundle_env_path "$label" "$name")/revisions/$r/deployments" >/dev/null || exit 1
    apigee_info "undeployed $label $name revision $r"
  done
}

# Prints revisions deployed in any environment.
bundle_deployed_any() {
  bundle_deployed_all "$1" "$2" | awk '{print $2}' | sort -un
}

bundle_delete_revisions() {
  local label="$1" name="$2"
  shift 2
  local revs deployed r todo="" failed=0
  revs="$(bundle_expand_revs "$@")" || exit 1
  deployed="$(bundle_deployed_any "$label" "$name")" || exit 1
  for r in $revs; do
    if printf '%s\n' "$deployed" | grep -x "$r" >/dev/null; then
      apigee_warn "skipping $label $name revision $r: it is deployed"
    else
      todo="$todo $r"
    fi
  done
  if [[ -z "${todo// /}" ]]; then
    apigee_info "nothing to delete for $label '$name'"
    return 0
  fi
  apigee_confirm "Delete $label '$name' revision(s)$todo."
  for r in $todo; do
    if apigee_request DELETE "$(bundle_path "$label" "$name")/revisions/$r" >/dev/null; then
      [[ "$APIGEE_DRY_RUN" == 1 ]] || apigee_info "deleted $label $name revision $r"
    else
      failed=1
    fi
  done
  return "$failed"
}

bundle_delete_revision_cmd() {
  local label="$1" name="${2:-}"
  bundle_require_name "$label" "$name" delete-revision
  shift 2
  (($#)) || apigee_die "missing REV"
  bundle_delete_revisions "$label" "$name" "$@"
}

bundle_clean_revisions() {
  local label="$1" keep=5 all=false names="" n
  shift
  while (($#)); do
    case "$1" in
      --keep) keep="$2"; shift 2 ;;
      --all) all=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) names="$names $1"; shift ;;
    esac
  done
  [[ "$keep" =~ ^[0-9]+$ && "$keep" -ge 1 ]] || apigee_die "--keep must be a positive integer"
  if [[ "$all" == true ]]; then
    names="$(bundle_list "$label")" || exit 1
  fi
  [[ -n "${names// /}" ]] || apigee_die "specify NAME... or --all"
  for n in $names; do
    local revs deployed candidates
    revs="$(bundle_revisions "$label" "$n")" || exit 1
    deployed="$(bundle_deployed_any "$label" "$n")" || exit 1
    candidates="$(printf '%s\n' "$revs" | sed '/^$/d' | sort -n | awk -v keep="$keep" '{a[NR]=$0} END {for (i = 1; i <= NR - keep; i++) print a[i]}')"
    if [[ -n "$deployed" && -n "$candidates" ]]; then
      candidates="$(printf '%s\n' "$candidates" | grep -vxF "$deployed" || true)"
    fi
    if [[ -z "$candidates" ]]; then
      apigee_info "$label $n: nothing to clean (keeping newest $keep and deployed revisions)"
      continue
    fi
    # shellcheck disable=SC2086
    bundle_delete_revisions "$label" "$n" $candidates
  done
}

bundle_unpack() {
  local zipfile="$1" dest="$2"
  apigee_have unzip || apigee_die "unzip is required for compare"
  mkdir -p "$dest"
  unzip -qo "$zipfile" -d "$dest"
}

bundle_compare() {
  local label="$1" name="" a="" b="" dir=""
  shift
  while (($#)); do
    case "$1" in
      --dir) dir="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *)
        if [[ -z "$name" ]]; then name="$1"; elif [[ -z "$a" ]]; then a="$1"; else b="$1"; fi
        shift
        ;;
    esac
  done
  bundle_require_name "$label" "$name" compare
  local work sub left right rc=0
  work="$(apigee_tmpdir)/compare"
  sub="$(bundle_dir_name "$label")"
  if [[ -n "$dir" ]]; then
    [[ -d "$dir" ]] || apigee_die "no such directory: $dir"
    if [[ -z "$a" ]]; then
      a="$(bundle_deployed_env "$label" "$name" | tail -n 1)"
      [[ -n "$a" ]] || a="$(bundle_latest "$label" "$name")"
    fi
    bundle_download_to "$label" "$name" "$a" "$work-$a.zip"
    bundle_unpack "$work-$a.zip" "$work/$a"
    left="$work/$a/$sub"
    if [[ -d "$dir/$sub" ]]; then right="$dir/$sub"; else right="$dir"; fi
    apigee_info "comparing $label $name revision $a with $right"
  else
    [[ -n "$a" ]] || a="$(bundle_latest "$label" "$name")"
    if [[ -z "$b" ]]; then
      b="$(bundle_deployed_env "$label" "$name" | tail -n 1)"
      [[ -n "$b" ]] || apigee_die "no REV_B given and $label '$name' is not deployed in $(apigee_env)"
    fi
    if [[ "$a" == "$b" ]]; then
      apigee_info "revisions are the same ($a)"
      return 0
    fi
    bundle_download_to "$label" "$name" "$a" "$work-$a.zip"
    bundle_download_to "$label" "$name" "$b" "$work-$b.zip"
    bundle_unpack "$work-$a.zip" "$work/$a"
    bundle_unpack "$work-$b.zip" "$work/$b"
    left="$work/$a/$sub"
    right="$work/$b/$sub"
    apigee_info "comparing $label $name revision $a with revision $b"
  fi
  diff -ru -x manifests -x .DS_Store "$left" "$right" || rc=$?
  return "$rc"
}

bundle_main() {
  local label="$1" verb="${2:-}"
  shift 2 || true
  case "$verb" in
    list) bundle_list "$label" ;;
    revisions) bundle_require_name "$label" "${1:-}" revisions; bundle_revisions "$label" "$1" ;;
    latest) bundle_require_name "$label" "${1:-}" latest; bundle_latest "$label" "$1" ;;
    deployed) bundle_deployed "$label" "$@" ;;
    download) bundle_download "$label" "$@" ;;
    import) bundle_import "$label" "$@" ;;
    deploy) bundle_deploy "$label" "$@" ;;
    undeploy) bundle_undeploy "$label" "$@" ;;
    delete-revision) bundle_delete_revision_cmd "$label" "$@" ;;
    clean-revisions) bundle_clean_revisions "$label" "$@" ;;
    compare) bundle_compare "$label" "$@" ;;
    *) apigee_die "unknown $label verb '$verb' (see 'apigee $label --help')" ;;
  esac
}
