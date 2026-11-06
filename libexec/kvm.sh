# shellcheck shell=bash
#
# apigee kvm <verb> — key value maps (environment, organization or proxy scope).
#
# Export format (JSON, lossless):
#   {"name": "<map>", "encrypted": true, "entries": [{"name": "k", "value": "v"}, ...]}
# Legacy "lines" format (one "key;value" per line; values starting with
# -----BEGIN may continue over several lines until the -----END line).

kvm_verbs() { printf '%s\n' list get create delete put export import; }

kvm_help() {
  case "${1:-}" in
    "")
      cat <<'EOF'
Usage: apigee kvm <verb> [--scope env|org|proxy:NAME] [options]

Verbs:
  list                         List key value maps in the scope
  get MAP [KEY]                Print a map (export document) or one value
  create MAP [--no-encrypt]    Create a map (encrypted by default)
  delete MAP [KEY]             Delete a map, or one entry
  put MAP KEY [VALUE]          Create or update an entry (--value-file, --value-stdin)
  export [MAP...]              Write maps to files (--out DIR, --format json|lines)
  import FILE|DIR...           Load maps from export files (creates missing maps)

Scope defaults to the current environment (--env). Encrypted Edge values are
masked by the management API; pass --reader-url URL (or APIGEE_KVM_READER_URL)
to read them through a helper proxy that answers GET URL?mapname=M&key=K.
Run 'apigee kvm <verb> --help' for details.
EOF
      ;;
    list) printf 'Usage: apigee kvm list [--scope env|org|proxy:NAME]\n\nList map names, one per line.\n' ;;
    get)
      cat <<'EOF'
Usage: apigee kvm get MAP [KEY] [--json] [--reader-url URL] [--scope ...]

Without KEY prints the whole map as an export document. With KEY prints the
raw value exactly as stored, including any trailing newline (a newline is only
added for display on a terminal), or the entry JSON with --json.
EOF
      ;;
    create)
      cat <<'EOF'
Usage: apigee kvm create MAP [--no-encrypt] [--scope ...]

Create an empty map. Maps are encrypted by default; --no-encrypt is Edge only
(Apigee X/hybrid maps are always encrypted). Mutating: asks for confirmation.
EOF
      ;;
    delete)
      cat <<'EOF'
Usage: apigee kvm delete MAP [KEY] [--scope ...]

Delete the whole map, or only entry KEY. Mutating: asks for confirmation.
EOF
      ;;
    put)
      cat <<'EOF'
Usage: apigee kvm put MAP KEY (VALUE | --value-file FILE | --value-stdin) [--scope ...]

Create the entry, or update it if it already exists. Prefer --value-file or
--value-stdin for secrets so the value never appears in process listings.
Mutating: asks for confirmation.
EOF
      ;;
    export)
      cat <<'EOF'
Usage: apigee kvm export [MAP...] [--out DIR] [--format json|lines] [--reader-url URL] [--scope ...]

Export the given maps (default: all maps in the scope) to DIR, one file per
map: MAP.json (default) or MAP.kvm (lines format). DIR defaults to
./kvm-export/<org>/<scope>. Export files may contain secrets; keep them out
of version control.
EOF
      ;;
    import)
      cat <<'EOF'
Usage: apigee kvm import FILE|DIR... [--map NAME] [--format json|lines] [--no-create]
                         [--allow-masked] [--scope ...]

Import export files (*.json documents, or *.kvm / other files in lines
format). The map name comes from the document, --map, or the file name.
Missing maps are created unless --no-create. Existing entries are updated.
Mutating: asks for confirmation once per file.

Edge masks the values of encrypted maps as "*****". If any value in any of
the files consists only of asterisks, nothing is imported (the offending map
and key names are listed). Pass --allow-masked to import such values anyway,
for example when a value really is a run of asterisks.
EOF
      ;;
    *) apigee_die "unknown kvm verb '$1' (see 'apigee kvm --help')" ;;
  esac
}

KVM_SCOPE="env"
KVM_READER_URL=""

kvm_prefix() {
  case "$KVM_SCOPE" in
    env) printf '%s/keyvaluemaps\n' "$(apigee_env_path)" ;;
    org) printf '%s/keyvaluemaps\n' "$(apigee_org_path)" ;;
    proxy:?*) printf '%s/apis/%s/keyvaluemaps\n' "$(apigee_org_path)" "$(apigee_urlencode "${KVM_SCOPE#proxy:}")" ;;
    *) apigee_die "bad --scope '$KVM_SCOPE' (use env, org or proxy:NAME)" ;;
  esac
}

kvm_scope_label() {
  case "$KVM_SCOPE" in
    env) apigee_env ;;
    org) printf 'org\n' ;;
    *) printf 'proxy-%s\n' "${KVM_SCOPE#proxy:}" ;;
  esac
}

kvm_map_path() {
  printf '%s/%s\n' "$(kvm_prefix)" "$(apigee_urlencode "$1")"
}

kvm_list() {
  local body
  body="$(apigee_get "$(kvm_prefix)")" || exit 1
  printf '%s' "$body" | apigee_json names | sort
}

kvm_reader_value() {
  local map="$1" key="$2" url
  url="$KVM_READER_URL?mapname=$(apigee_urlencode "$map")&key=$(apigee_urlencode "$key")"
  if [[ "${APIGEE_KVM_READER_AUTH:-none}" == bearer ]]; then
    apigee_request GET "$url" --accept '*/*' --reader-auth
  else
    apigee_request GET "$url" --accept '*/*' --no-auth
  fi
}

# Print the entries of MAP as compact JSON lines; sets KVM_ENCRYPTED.
KVM_ENCRYPTED=true
kvm_fetch_entries() {
  local map="$1" out
  out="$(apigee_mktemp entries)"
  if [[ "$APIGEE_KIND" == x ]]; then
    local token="" page body
    while :; do
      page="$(kvm_map_path "$map")/entries?pageSize=100"
      [[ -n "$token" ]] && page="$page&pageToken=$(apigee_urlencode "$token")"
      body="$(apigee_get "$page")" || exit 1
      printf '%s' "$body" | apigee_json kvm-entries >>"$out"
      token="$(printf '%s' "$body" | apigee_json get nextPageToken)"
      [[ -n "$token" ]] || break
    done
    KVM_ENCRYPTED=true
  else
    local body
    body="$(apigee_get "$(kvm_map_path "$map")")" || exit 1
    printf '%s' "$body" | apigee_json kvm-entries >"$out"
    KVM_ENCRYPTED="$(printf '%s' "$body" | apigee_json get encrypted)"
    [[ -n "$KVM_ENCRYPTED" ]] || KVM_ENCRYPTED=false
  fi
  if [[ -n "$KVM_READER_URL" ]]; then
    local line name value_file
    value_file="$(apigee_mktemp value)"
    while IFS= read -r line; do
      name="$(printf '%s' "$line" | apigee_json get name)"
      kvm_reader_value "$map" "$name" >"$value_file" || exit 1
      apigee_json kvm-entry "$name" <"$value_file"
    done <"$out"
    rm -f "$value_file"
  else
    if [[ "$KVM_ENCRYPTED" == true && "$APIGEE_KIND" == edge ]] && grep -q '"value":"\*\*\*\*\*"' "$out"; then
      apigee_warn "map '$map' is encrypted: Edge masks its values; use --reader-url to export real values"
    fi
    cat "$out"
  fi
  rm -f "$out"
}

kvm_doc() {
  local map="$1" entries
  entries="$(apigee_mktemp doc)"
  kvm_fetch_entries "$map" >"$entries"
  apigee_json kvm-doc "$map" "$KVM_ENCRYPTED" <"$entries"
  rm -f "$entries"
}

kvm_get() {
  local map="" key="" json=false
  while (($#)); do
    case "$1" in
      --json) json=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) if [[ -z "$map" ]]; then map="$1"; else key="$1"; fi; shift ;;
    esac
  done
  [[ -n "$map" ]] || apigee_die "missing MAP"
  if [[ -z "$key" ]]; then
    kvm_doc "$map"
    return
  fi
  local value_file body
  value_file="$(apigee_mktemp value)"
  if [[ -n "$KVM_READER_URL" ]]; then
    kvm_reader_value "$map" "$key" >"$value_file" || exit 1
  else
    body="$(apigee_get "$(kvm_map_path "$map")/entries/$(apigee_urlencode "$key")")" || exit 1
    printf '%s' "$body" | apigee_json get-raw value >"$value_file"
  fi
  if [[ "$json" == true ]]; then
    apigee_json kvm-entry "$key" <"$value_file"
  else
    cat "$value_file"
    if [[ -t 1 && -n "$(tail -c 1 "$value_file")" ]]; then
      printf '\n'
    fi
  fi
  rm -f "$value_file"
}

kvm_create_map() {
  local map="$1" encrypted="$2"
  if [[ "$APIGEE_KIND" == x && "$encrypted" != true ]]; then
    apigee_die "Apigee X/hybrid key value maps are always encrypted (drop --no-encrypt)"
  fi
  local body
  body="$(apigee_json build "name=$map" "encrypted:=$encrypted")"
  apigee_request POST "$(kvm_prefix)" --json "$body" >/dev/null
}

kvm_create() {
  local map="" encrypted=true
  while (($#)); do
    case "$1" in
      --no-encrypt) encrypted=false; shift ;;
      --encrypt | --encrypted) encrypted=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) map="$1"; shift ;;
    esac
  done
  [[ -n "$map" ]] || apigee_die "missing MAP"
  apigee_confirm "Create key value map '$map' ($(kvm_scope_label) scope, encrypted=$encrypted)."
  kvm_create_map "$map" "$encrypted" || exit 1
  [[ "$APIGEE_DRY_RUN" == 1 ]] || apigee_info "created key value map $map"
}

kvm_delete() {
  local map="${1:-}" key="${2:-}"
  [[ -n "$map" ]] || apigee_die "missing MAP"
  if [[ -n "$key" ]]; then
    apigee_confirm "Delete entry '$key' from key value map '$map'."
    apigee_request DELETE "$(kvm_map_path "$map")/entries/$(apigee_urlencode "$key")" >/dev/null || exit 1
  else
    apigee_confirm "Delete key value map '$map' and all of its entries."
    apigee_request DELETE "$(kvm_map_path "$map")" >/dev/null || exit 1
  fi
}

# Create or update one entry. $2 is a file holding the compact entry JSON.
kvm_put_entry_file() {
  local map="$1" file="$2" key
  key="$(apigee_json get name <"$file")"
  [[ -n "$key" ]] || apigee_die "entry without a name in $file"
  apigee_request POST "$(kvm_map_path "$map")/entries" --data-file "$file" --ok 409 >/dev/null || return 1
  if [[ "$(apigee_last_status)" == 409 ]]; then
    local entry_path
    entry_path="$(kvm_map_path "$map")/entries/$(apigee_urlencode "$key")"
    if [[ "$APIGEE_KIND" == x ]]; then
      apigee_request PUT "$entry_path" --data-file "$file" >/dev/null || return 1
    else
      apigee_request POST "$entry_path" --data-file "$file" >/dev/null || return 1
    fi
  fi
}

kvm_put() {
  local map="" key="" value="" have_value=false value_file="" from_stdin=false
  while (($#)); do
    case "$1" in
      --value-file) value_file="$2"; shift 2 ;;
      --value-stdin) from_stdin=true; shift ;;
      --) shift; value="${1:-}"; have_value=true; break ;;
      -*) apigee_die "unknown option $1" ;;
      *)
        if [[ -z "$map" ]]; then map="$1"; elif [[ -z "$key" ]]; then key="$1"; else value="$1"; have_value=true; fi
        shift
        ;;
    esac
  done
  [[ -n "$map" && -n "$key" ]] || apigee_die "usage: apigee kvm put MAP KEY (VALUE | --value-file FILE | --value-stdin)"
  local entry
  entry="$(apigee_mktemp entry)"
  if [[ -n "$value_file" ]]; then
    [[ -f "$value_file" ]] || apigee_die "no such file: $value_file"
    apigee_json kvm-entry "$key" <"$value_file" >"$entry"
  elif [[ "$from_stdin" == true ]]; then
    apigee_json kvm-entry "$key" >"$entry"
  elif [[ "$have_value" == true ]]; then
    printf '%s' "$value" | apigee_json kvm-entry "$key" >"$entry"
  else
    apigee_die "missing VALUE (or --value-file / --value-stdin)"
  fi
  apigee_confirm "Set entry '$key' in key value map '$map'."
  kvm_put_entry_file "$map" "$entry" || exit 1
  rm -f "$entry"
}

# Parse the legacy "key;value" format into compact entry JSON lines.
kvm_parse_lines() {
  local file="$1" line key value collecting=false buffer="" current=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$collecting" == true ]]; then
      buffer="$buffer"$'\n'"$line"
      if [[ "$line" == *-----END* ]]; then
        printf '{"name":%s,"value":%s}\n' "$(apigee_json_string "$current")" "$(apigee_json_string "$buffer")"
        collecting=false
        buffer=""
      fi
      continue
    fi
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" != *";"* ]]; then
      apigee_warn "$file: skipping line without ';'"
      continue
    fi
    key="${line%%;*}"
    value="${line#*;}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    if [[ "$value" == -----BEGIN* && "$value" != *-----END* ]]; then
      collecting=true
      current="$key"
      buffer="$value"
      continue
    fi
    printf '{"name":%s,"value":%s}\n' "$(apigee_json_string "$key")" "$(apigee_json_string "$value")"
  done <"$file"
  if [[ "$collecting" == true ]]; then
    apigee_die "$file: entry '$current' has -----BEGIN without -----END"
  fi
}

kvm_write_lines() {
  local entries="$1" dest="$2" name value line
  while IFS= read -r line; do
    name="$(printf '%s' "$line" | apigee_json get name)"
    value="$(printf '%s' "$line" | apigee_json get value)"
    if [[ "$name" == *";"* ]]; then
      apigee_warn "key '$name' contains ';'; use --format json for an exact export"
    fi
    if [[ "$value" == *$'\n'* && "$value" != -----BEGIN* ]]; then
      apigee_warn "value of '$name' is multi-line; use --format json for an exact export"
    fi
  done <"$entries"
  apigee_json entries-to-lines <"$entries" >"$dest"
}

kvm_export() {
  local maps="" out="" format=json m
  while (($#)); do
    case "$1" in
      --out | -o) out="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) maps="$maps $1"; shift ;;
    esac
  done
  [[ "$format" == json || "$format" == lines ]] || apigee_die "--format must be json or lines"
  out="${out:-./kvm-export/$(apigee_org)/$(kvm_scope_label)}"
  if [[ -z "${maps// /}" ]]; then
    maps="$(kvm_list)" || exit 1
  fi
  (umask 077 && mkdir -p "$out")
  for m in $maps; do
    local entries
    entries="$(apigee_mktemp export)"
    kvm_fetch_entries "$m" >"$entries"
    if [[ "$format" == json ]]; then
      (umask 077 && apigee_json kvm-doc "$m" "$KVM_ENCRYPTED" <"$entries" >"$out/$m.json")
      apigee_info "exported $m -> $out/$m.json ($(wc -l <"$entries" | tr -d ' ') entries)"
    else
      (umask 077 && kvm_write_lines "$entries" "$out/$m.kvm")
      apigee_info "exported $m -> $out/$m.kvm ($(wc -l <"$entries" | tr -d ' ') entries)"
    fi
    rm -f "$entries"
  done
}

# Parse every import file once, before anything is written. Prints one
# tab-separated "ENTRIES_FILE FORMAT FILE" line per input file.
kvm_parse_inputs() {
  local list="$1" format="$2" f fmt entries
  while IFS= read -r f; do
    fmt="$format"
    if [[ -z "$fmt" ]]; then
      if [[ "$f" == *.json ]]; then fmt=json; else fmt=lines; fi
    fi
    entries="$(apigee_mktemp import)"
    if [[ "$fmt" == json ]]; then
      apigee_json kvm-entries <"$f" >"$entries" || apigee_die "$f: not a valid export document"
    else
      kvm_parse_lines "$f" >"$entries" || exit 1
    fi
    printf '%s\t%s\t%s\n' "$entries" "$fmt" "$f"
  done <"$list"
}

# Exit unless every value is real (not an Edge "*****" mask).
kvm_refuse_masked() {
  local parsed="$1" entries fmt f keys found=""
  while IFS=$'\t' read -r entries fmt f; do
    keys="$(apigee_json masked-keys <"$entries")"
    if [[ -n "$keys" ]]; then
      found="$found  $f: $(printf '%s' "$keys" | tr '\n' ' ')
"
    fi
  done <"$parsed"
  if [[ -n "$found" ]]; then
    printf 'masked values (all asterisks) found for these keys:\n%s' "$found" >&2
    apigee_die "refusing to import masked values over real ones; re-export with --reader-url, or pass --allow-masked"
  fi
}

kvm_import_file() {
  local file="$1" entries="$2" format="$3" map="$4" create="$5" encrypted=true
  if [[ "$format" == json ]]; then
    [[ -n "$map" ]] || map="$(apigee_json get name <"$file")"
    encrypted="$(apigee_json get encrypted <"$file")"
    [[ -n "$encrypted" ]] || encrypted=true
  elif [[ -z "$map" ]]; then
    map="$(basename "$file")"
    map="${map%.*}"
  fi
  [[ -n "$map" ]] || apigee_die "$file: cannot determine map name (use --map)"
  [[ "$APIGEE_KIND" == x ]] && encrypted=true
  local count exists=false maps
  count="$(wc -l <"$entries" | tr -d ' ')"
  maps="$(kvm_list)" || exit 1
  if printf '%s\n' "$maps" | grep -xF "$map" >/dev/null; then
    exists=true
  elif [[ "$create" != true ]]; then
    apigee_die "key value map '$map' does not exist (drop --no-create to create it)"
  fi
  if [[ "$exists" == true ]]; then
    apigee_confirm "Import $count entries from $file into key value map '$map'."
  else
    apigee_confirm "Create key value map '$map' (encrypted=$encrypted) and import $count entries from $file."
    kvm_create_map "$map" "$encrypted" || exit 1
  fi
  local line one failed=0
  one="$(apigee_mktemp one)"
  while IFS= read -r line; do
    printf '%s\n' "$line" >"$one"
    kvm_put_entry_file "$map" "$one" || failed=1
  done <"$entries"
  rm -f "$one" "$entries"
  [[ "$APIGEE_DRY_RUN" == 1 ]] || apigee_info "imported $count entries into $map"
  return "$failed"
}

kvm_import() {
  local files="" map="" format="" create=true allow_masked=false failed=0
  local list parsed entries fmt f
  list="$(apigee_mktemp files)"
  while (($#)); do
    case "$1" in
      --map) map="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      --no-create) create=false; shift ;;
      --allow-masked) allow_masked=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *)
        if [[ -d "$1" ]]; then
          find "$1" -maxdepth 1 -type f \( -name '*.json' -o -name '*.kvm' \) | sort >>"$list"
        elif [[ -f "$1" ]]; then
          printf '%s\n' "$1" >>"$list"
        else
          apigee_die "no such file or directory: $1"
        fi
        files=yes
        shift
        ;;
    esac
  done
  [[ -n "$files" ]] || apigee_die "missing FILE or DIR"
  [[ -z "$format" || "$format" == json || "$format" == lines ]] || apigee_die "--format must be json or lines"
  parsed="$(apigee_mktemp parsed)"
  kvm_parse_inputs "$list" "$format" >"$parsed"
  if [[ "$allow_masked" == true ]]; then
    apigee_warn "--allow-masked: values consisting only of asterisks will be imported as-is"
  else
    kvm_refuse_masked "$parsed"
  fi
  while IFS=$'\t' read -r entries fmt f; do
    kvm_import_file "$f" "$entries" "$fmt" "$map" "$create" || failed=1
  done <"$parsed"
  return "$failed"
}

kvm_main() {
  local verb="${1:-}"
  shift || true
  local args=() a
  KVM_READER_URL="${APIGEE_KVM_READER_URL:-}"
  while (($#)); do
    a="$1"
    case "$a" in
      --scope) KVM_SCOPE="$2"; shift 2 ;;
      --scope=*) KVM_SCOPE="${a#--scope=}"; shift ;;
      --reader-url) KVM_READER_URL="$2"; shift 2 ;;
      *) args+=("$a"); shift ;;
    esac
  done
  set -- ${args[@]+"${args[@]}"}
  case "$verb" in
    list) kvm_list ;;
    get) kvm_get "$@" ;;
    create) kvm_create "$@" ;;
    delete) kvm_delete "$@" ;;
    put) kvm_put "$@" ;;
    export) kvm_export "$@" ;;
    import) kvm_import "$@" ;;
    *) apigee_die "unknown kvm verb '$verb' (see 'apigee kvm --help')" ;;
  esac
}
