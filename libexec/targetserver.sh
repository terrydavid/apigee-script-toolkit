# shellcheck shell=bash
#
# apigee target-server <verb> — environment target servers.

targetserver_verbs() { printf '%s\n' list get create update delete; }

targetserver_help() {
  case "${1:-}" in
    "")
      cat <<'EOF'
Usage: apigee target-server <verb> [options]

Verbs:
  list                 List target servers in --env
  get NAME             Show a target server
  create NAME ...      Create (--host H --port P [--ssl] [--disabled] | --file JSON)
  update NAME ...      Update; only the given fields change (or --file JSON)
  delete NAME          Delete a target server

Run 'apigee target-server <verb> --help' for details.
EOF
      ;;
    list) printf 'Usage: apigee target-server list\n\nList target server names in --env.\n' ;;
    get) printf 'Usage: apigee target-server get NAME\n\nPrint the target server definition as JSON.\n' ;;
    create | update)
      cat <<EOF
Usage: apigee target-server $1 NAME [--host HOST] [--port PORT] [--ssl | --no-ssl]
                                 [--enabled | --disabled] [--protocol HTTP|GRPC] [--file JSON]

$( [[ "$1" == create ]] && printf 'Create a target server. --host and --port are required unless --file is given.' || printf 'Update a target server. Fields not given keep their current value.')
--file supplies the full JSON body instead (Apigee TargetServer format).
--protocol is Apigee X/hybrid only. Mutating: asks for confirmation.
EOF
      ;;
    delete) printf 'Usage: apigee target-server delete NAME\n\nDelete a target server. Mutating: asks for confirmation.\n' ;;
    *) apigee_die "unknown target-server verb '$1' (see 'apigee target-server --help')" ;;
  esac
}

targetserver_path() {
  printf '%s/targetservers%s\n' "$(apigee_env_path)" "${1:+/$(apigee_urlencode "$1")}"
}

targetserver_body() {
  local mode="$1" name="$2" host="$3" port="$4" ssl="$5" enabled="$6" protocol="$7"
  local args=("name=$name")
  if [[ "$mode" == create ]]; then
    [[ -n "$host" && -n "$port" ]] || apigee_die "create needs --host and --port (or --file)"
    [[ -n "$enabled" ]] || enabled=true
  fi
  [[ -n "$host" ]] && args+=("host=$host")
  if [[ -n "$port" ]]; then
    [[ "$port" =~ ^[0-9]+$ ]] || apigee_die "--port must be numeric"
    args+=("port:=$port")
  fi
  [[ -n "$enabled" ]] && args+=("isEnabled:=$enabled")
  [[ -n "$ssl" ]] && args+=("sSLInfo:={\"enabled\":$ssl}")
  if [[ -n "$protocol" ]]; then
    apigee_require_platform x "--protocol"
    args+=("protocol=$protocol")
  fi
  apigee_json build "${args[@]}"
}

targetserver_write() {
  local mode="$1"
  shift
  local name="" host="" port="" ssl="" enabled="" protocol="" file=""
  while (($#)); do
    case "$1" in
      --host) host="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --ssl) ssl=true; shift ;;
      --no-ssl) ssl=false; shift ;;
      --enabled) enabled=true; shift ;;
      --disabled) enabled=false; shift ;;
      --protocol) protocol="$2"; shift 2 ;;
      --file) file="$2"; shift 2 ;;
      -*) apigee_die "unknown option $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [[ -n "$name" ]] || apigee_die "missing NAME"
  local body
  if [[ -n "$file" ]]; then
    [[ -f "$file" ]] || apigee_die "no such file: $file"
    body="$(cat "$file")"
  elif [[ "$mode" == create ]]; then
    body="$(targetserver_body create "$name" "$host" "$port" "$ssl" "$enabled" "$protocol")" || exit 1
  else
    local current override
    current="$(apigee_get "$(targetserver_path "$name")")" || exit 1
    override="$(targetserver_body update "$name" "$host" "$port" "$ssl" "$enabled" "$protocol")" || exit 1
    body="$(printf '%s' "$current" | apigee_json merge "$override")"
  fi
  local out
  if [[ "$mode" == create ]]; then
    apigee_confirm "Create target server '$name' in '$(apigee_env)'."
    out="$(apigee_request POST "$(targetserver_path)" --json "$body")" || exit 1
  else
    apigee_confirm "Update target server '$name' in '$(apigee_env)'."
    out="$(apigee_request PUT "$(targetserver_path "$name")" --json "$body")" || exit 1
  fi
  if [[ -n "$out" ]]; then
    printf '%s' "$out" | apigee_json pretty
  fi
}

targetserver_main() {
  local verb="${1:-}"
  shift || true
  case "$verb" in
    list)
      local body
      body="$(apigee_get "$(targetserver_path)")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      [[ -n "${1:-}" ]] || apigee_die "missing NAME"
      apigee_get "$(targetserver_path "$1")" | apigee_json pretty
      ;;
    create | update) targetserver_write "$verb" "$@" ;;
    delete)
      [[ -n "${1:-}" ]] || apigee_die "missing NAME"
      apigee_confirm "Delete target server '$1' from '$(apigee_env)'."
      apigee_request DELETE "$(targetserver_path "$1")" >/dev/null
      ;;
    *) apigee_die "unknown target-server verb '$verb' (see 'apigee target-server --help')" ;;
  esac
}
