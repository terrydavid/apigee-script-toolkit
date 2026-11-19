# shellcheck shell=bash
#
# Edge / OPDK write verbs for caches, virtual hosts and keystores.
# Replaces createCache, deleteCache, getCache, createVirtualHost,
# createSslVirtualHost, updateVirtualHost, putVHost, deleteVirtualHost,
# createManyVHosts and uploadKeyCert. Key passwords are read from
# APIGEE_KEY_PASSWORD (never from arguments) and sent via a curl config file.

edge_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

edge_arr() {
  local out="" v
  for v in "$@"; do out="$out${out:+,}\"$(edge_esc "$v")\""; done
  printf '[%s]' "$out"
}

# --- cache ------------------------------------------------------------------

cache_write() { # create|get|delete args...
  local verb="$1" name="" desc="" timeout=300 maxmem=100 maxdisk=0 mem_kb=0 disk_mb=0 overflow=false persistent=false
  shift
  while (($#)); do
    case "$1" in
      --description) desc="${2:?}"; shift 2 ;;
      --timeout) timeout="${2:?}"; shift 2 ;;
      --max-elements) maxmem="${2:?}"; shift 2 ;;
      --max-elements-disk) maxdisk="${2:?}"; shift 2 ;;
      --size-kb) mem_kb="${2:?}"; shift 2 ;;
      --disk-mb) disk_mb="${2:?}"; shift 2 ;;
      --overflow-to-disk) overflow=true; shift ;;
      --persistent) persistent=true; shift ;;
      -*) apigee_die "unknown option $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [[ -n "$name" ]] || apigee_die "missing NAME"
  local path="$(apigee_env_path)/caches"
  case "$verb" in
    create)
      apigee_confirm "Create cache '$name' in '$(apigee_env)'."
      apigee_request POST "$path" --json "{\"name\":\"$(edge_esc "$name")\",\"description\":\"$(edge_esc "$desc")\",\"expirySettings\":{\"timeoutInSec\":{\"value\":\"$timeout\"}},\"maxElementsInMemory\":$maxmem,\"maxElementsOnDisk\":$maxdisk,\"inMemorySizeInKB\":$mem_kb,\"diskSizeInMB\":$disk_mb,\"overflowToDisk\":$overflow,\"persistent\":$persistent}" | apigee_json pretty
      ;;
    get) apigee_get "$path/$(apigee_urlencode "$name")" | apigee_json pretty ;;
    delete)
      apigee_confirm "Delete cache '$name' in '$(apigee_env)'."
      apigee_request DELETE "$path/$(apigee_urlencode "$name")" >/dev/null
      apigee_info "deleted cache $name"
      ;;
  esac
}

# --- virtual hosts ------------------------------------------------------------

vhost_write() { # create|update|delete args...
  local verb="$1" name="" port="" aliases=() ks="" kalias="" from="" body path
  shift
  while (($#)); do
    case "$1" in
      --port) port="${2:?}"; shift 2 ;;
      --alias) aliases+=("${2:?}"); shift 2 ;;
      --keystore) ks="${2:?}"; shift 2 ;;
      --key-alias) kalias="${2:?}"; shift 2 ;;
      --from-file) from="${2:?}"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  path="$(apigee_env_path)/virtualhosts"
  case "$verb" in
    create)
      if [[ -n "$from" ]]; then
        [[ -f "$from" ]] || apigee_die "no such file: $from"
        body="$(apigee_json omit <"$from")" || exit 1
        name="$(printf '%s' "$body" | apigee_json get name)"
      else
        [[ -n "$name" ]] || apigee_die "missing NAME"
        [[ -n "$port" ]] || apigee_die "missing --port"
        body="{\"name\":\"$(edge_esc "$name")\",\"hostAliases\":$(edge_arr "${aliases[@]+"${aliases[@]}"}"),\"interfaces\":[],\"port\":\"$port\""
        if [[ -n "$ks" ]]; then
          body="$body,\"sSLInfo\":{\"enabled\":true,\"clientAuthEnabled\":false,\"keyStore\":\"$(edge_esc "$ks")\"${kalias:+,\"keyAlias\":\"$(edge_esc "$kalias")\"},\"ignoreValidationErrors\":false}"
        fi
        body="$body}"
      fi
      apigee_confirm "Create virtual host '$name' in '$(apigee_env)'."
      apigee_request POST "$path" --json "$body" | apigee_json pretty
      ;;
    update)
      [[ -n "$name" ]] || apigee_die "missing NAME"
      local doc patch=""
      if [[ -n "$from" ]]; then
        [[ -f "$from" ]] || apigee_die "no such file: $from"
        body="$(apigee_json omit <"$from")" || exit 1
      else
        doc="$(apigee_get "$path/$(apigee_urlencode "$name")")" || exit 1
        ((${#aliases[@]})) && patch="\"hostAliases\":$(edge_arr "${aliases[@]}")"
        [[ -n "$port" ]] && patch="$patch${patch:+,}\"port\":\"$port\""
        [[ -n "$patch" ]] || apigee_die "nothing to change (use --port, --alias or --from-file)"
        body="$(printf '%s' "$doc" | apigee_json merge "{$patch}" | apigee_json omit)" || exit 1
      fi
      apigee_confirm "Update virtual host '$name' in '$(apigee_env)'."
      apigee_request PUT "$path/$(apigee_urlencode "$name")" --json "$body" | apigee_json pretty
      ;;
    delete)
      [[ -n "$name" ]] || apigee_die "missing NAME"
      apigee_confirm "Delete virtual host '$name' in '$(apigee_env)'."
      apigee_request DELETE "$path/$(apigee_urlencode "$name")" >/dev/null
      apigee_info "deleted virtual host $name"
      ;;
  esac
}

# --- keystore / truststore writes -----------------------------------------------

keystore_write() { # label verb args...
  local label="$1" verb="$2" name="" alias="" keyfile="" certfile="" fmt
  shift 2
  while (($#)); do
    case "$1" in
      --alias) alias="${2:?}"; shift 2 ;;
      --key-file) keyfile="${2:?}"; shift 2 ;;
      --cert-file) certfile="${2:?}"; shift 2 ;;
      -*) apigee_die "unknown option $1 (key passwords come from APIGEE_KEY_PASSWORD, never from arguments)" ;;
      *) name="$1"; shift ;;
    esac
  done
  [[ -n "$name" ]] || apigee_die "missing NAME"
  case "$verb" in
    create)
      apigee_confirm "Create $label '$name' in '$(apigee_env)'."
      apigee_request POST "$(keystore_path)" --json "{\"name\":\"$(edge_esc "$name")\"}" | apigee_json pretty
      ;;
    delete)
      apigee_confirm "Delete $label '$name' and everything in it, in '$(apigee_env)'."
      apigee_request DELETE "$(keystore_path "$name")" >/dev/null
      apigee_info "deleted $label $name"
      ;;
    upload-cert)
      [[ -n "$alias" ]] || apigee_die "missing --alias"
      [[ -n "$certfile" && -f "$certfile" ]] || apigee_die "missing or unreadable --cert-file"
      local forms=()
      if [[ -n "$keyfile" ]]; then
        [[ -f "$keyfile" ]] || apigee_die "no such file: $keyfile"
        fmt=keycertfile
        forms=(--form "keyFile=@$keyfile" --form "certFile=@$certfile")
        [[ -z "${APIGEE_KEY_PASSWORD:-}" ]] || forms+=(--form-secret "password=$APIGEE_KEY_PASSWORD")
      else
        fmt=pem
        forms=(--form "file=@$certfile")
      fi
      apigee_confirm "Upload '$alias' to $label '$name' in '$(apigee_env)'."
      apigee_request POST "$(keystore_path "$name")/aliases?alias=$(apigee_urlencode "$alias")&format=$fmt" "${forms[@]}" | apigee_json pretty
      ;;
  esac
}
