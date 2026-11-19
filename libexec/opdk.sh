# shellcheck shell=bash
#
# Edge for Private Cloud (OPDK) infrastructure; --platform opdk only:
#   apigee server list|get UUID|env-servers|org-servers|ips|names|attach UUID|detach UUID|health HOST
#
# Replaces the legacy getServers, getSrvrFmUuid, getSrvrIPaddr, getSrvrIPs, getSrvrNames,
# getEnvSrvrUuid, getEnvironmentServers, addEnvironmentServer, deleteEnvironmentServer,
# zkDereg and chkNodes.

server_verbs() { printf '%s\n' list get env-servers org-servers ips names attach detach health; }

server_help() {
  case "${1:-}" in
    "") printf 'Usage: apigee server <verb>   (OPDK only)\n\nVerbs:\n  list                 All servers known to the management server\n  get UUID             One server (internal and external IP, type, pod)\n  env-servers          Message processors serving --env (UUIDs)\n  org-servers          Servers of the organization (UUIDs)\n  ips [--internal]     "UUID IP" for every organization server (external IPs by default)\n  names                "UUID DNSNAME" by reverse lookup of the internal IPs (needs `host`)\n  attach UUID          Add a message processor to --env (mutating)\n  detach UUID          Remove a message processor from --env (mutating)\n  health HOST          Check /v1/servers/self/up on ports 8080 8081 8082 of HOST\n\nOverride the ports with APIGEE_OPDK_PORTS="8080 8081".\n' ;;
    health) printf 'Usage: apigee server health HOST\n\nGET http://HOST:PORT/v1/servers/self/up for each port (default 8080 management,\n8081 router, 8082 message processor; override with APIGEE_OPDK_PORTS). Sends no\ncredentials. Exit status 1 if any port is down.\n' ;;
    attach | detach) printf 'Usage: apigee server %s UUID   (uses --env)\n\nAdd/remove a message processor to/from the environment. Mutating: asks for\nconfirmation; -n/--dry-run shows the request.\n' "$1" ;;
    *) printf 'Usage: apigee server %s\n\nSee "apigee server --help".\n' "$1" ;;
  esac
}

server_main() {
  apigee_require_platform opdk "apigee server"
  local verb="${1:-}" uuid="${2:-}" body ip field
  case "$verb" in
    list)
      body="$(apigee_get /servers)" || exit 1
      printf '%s' "$body" | apigee_json names
      ;;
    get)
      [[ -n "$uuid" ]] || apigee_die "missing UUID"
      apigee_get "/servers/$(apigee_urlencode "$uuid")" | apigee_json pretty
      ;;
    env-servers)
      body="$(apigee_get "$(apigee_env_path)/servers")" || exit 1
      printf '%s' "$body" | apigee_json names
      ;;
    org-servers)
      body="$(apigee_get "$(apigee_org_path)/servers")" || exit 1
      printf '%s' "$body" | apigee_json names
      ;;
    ips)
      field=externalIP
      [[ "$uuid" == --internal ]] && field=internalIP
      while IFS= read -r uuid; do
        [[ -n "$uuid" ]] || continue
        ip="$(apigee_get "/servers/$(apigee_urlencode "$uuid")" | apigee_json get "$field")"
        printf '%s %s\n' "$uuid" "$ip"
      done < <(server_main org-servers)
      ;;
    names)
      apigee_have host || apigee_die "'host' is needed for reverse lookups"
      while IFS= read -r uuid; do
        [[ -n "$uuid" ]] || continue
        ip="$(apigee_get "/servers/$(apigee_urlencode "$uuid")" | apigee_json get internalIP)"
        printf '%s %s\n' "$uuid" "$(host "$ip" | awk '/pointer/ {print $5}' | sed 's/\.$//')"
      done < <(server_main org-servers)
      ;;
    attach | detach)
      [[ -n "$uuid" ]] || apigee_die "missing UUID"
      local action=add
      [[ "$verb" == detach ]] && action=remove
      apigee_confirm "$verb server '$uuid' ${action/add/to}${action/remove/from} environment '$(apigee_env)' in org '$(apigee_org)'."
      apigee_request POST "$(apigee_env_path)/servers" --json "action=$action&uuid=$(apigee_urlencode "$uuid")" \
        --content-type application/x-www-form-urlencoded >/dev/null
      apigee_info "$verb: server $uuid, environment $(apigee_env)"
      ;;
    health)
      [[ -n "$uuid" ]] || apigee_die "missing HOST"
      local port down=0
      for port in ${APIGEE_OPDK_PORTS:-8080 8081 8082}; do
        if apigee_get "http://$uuid:$port/v1/servers/self/up" --no-auth --ok 400,401,403,404,500,502,503 >/dev/null 2>&1 \
          && [[ "$(apigee_last_status)" == 200 ]]; then
          printf '%s ok\n' "$port"
        else
          printf '%s DOWN (status %s)\n' "$port" "$(apigee_last_status 2>/dev/null)"
          down=1
        fi
      done
      return "$down"
      ;;
    *) apigee_die "unknown server verb '$verb' (see 'apigee server --help')" ;;
  esac
}
