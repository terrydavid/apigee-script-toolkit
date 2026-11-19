# shellcheck shell=bash
# bash completion for bin/apigee (apigee-toolkit).
#
# Install:  setup/install-completion.sh          (adds a source line to ~/.bashrc)
# Or add    source /path/to/apigee-toolkit/completions/apigee.bash   to ~/.bashrc.
#
# Completes: global options (and their values), resources and aliases, verbs
# per resource, per-verb options, and profile names. The verb table is checked
# against the modules in libexec/ by tests/test_completion.sh.

_apigee_resources="proxy sharedflow kvm target-server keystore truststore app developer product credential role resourcefile audit raw appgroup datacollector datastore reference securityprofile site endpoint operation apicategory apidoc flowhook trace iam sync cache env virtualhost envgroup instance server stats report user org token sa profile doctor"
_apigee_aliases="proxies api apis sharedflows sf kvms keyvaluemap target-servers targetserver ts keystores truststores apps developers dev products apiproduct credentials key keys roles resource resourcefiles caches envs environment environments virtualhosts vhost envgroups instances servers stat reports users organization profiles"
_apigee_global_opts="--platform --org --env --profile -n --dry-run -y --yes --debug --json-engine --version -h --help"
_apigee_bundle_verbs="list revisions latest deployed stale export download import deploy undeploy delete delete-revision clean-revisions compare"

# canonical resource name for a typed resource/alias (empty if unknown)
_apigee_canon() {
  case "$1" in
    proxy | proxies | api | apis) echo proxy ;;
    sharedflow | sharedflows | sf) echo sharedflow ;;
    kvm | kvms | keyvaluemap) echo kvm ;;
    target-server | target-servers | targetserver | ts) echo targetserver ;;
    keystore | keystores) echo keystore ;;
    truststore | truststores) echo truststore ;;
    app | apps) echo app ;;
    credential | credentials | key | keys) echo credential ;;
    role | roles | userrole | userroles) echo role ;;
    resourcefile | resourcefiles | resource) echo resourcefile ;;
    developer | developers | dev) echo developer ;;
    product | products | apiproduct) echo product ;;
    cache | caches) echo cache ;;
    env | envs | environment | environments) echo env ;;
    virtualhost | virtualhosts | vhost) echo virtualhost ;;
    envgroup | envgroups) echo envgroup ;;
    instance | instances) echo instance ;;
    stats | stat) echo stats ;;
    server | servers) echo server ;;
    report | reports) echo report ;;
    user | users) echo user ;;
    org | organization) echo org ;;
    token) echo token ;;
    sa | serviceaccount | service-account) echo sa ;;
    profile | profiles) echo profile ;;
    doctor) echo doctor ;;
  esac
}

_apigee_verbs_for() {
  case "$1" in
    proxy | sharedflow) echo "$_apigee_bundle_verbs" ;;
    kvm) echo "list get create delete flush put export import" ;;
    targetserver) echo "list get create update delete" ;;
    keystore | truststore) echo "list get create delete upload-cert aliases alias-get alias-delete cert csr self-signed" ;;
    app) echo "list get approve revoke create delete export import" ;;
    developer) echo "list get create delete export import" ;;
    product) echo "list get create delete attach-proxy detach-proxy proxies find export import" ;;
    credential) echo "list get add set-products delete delete-all" ;;
    role) echo "list create delete add-user remove-user users permissions" ;;
    resourcefile) echo "list get upload delete revision" ;;
    audit) echo "products apps" ;;
    appgroup | datacollector | datastore | reference | securityprofile | site | endpoint | apicategory | apidoc) echo "list get create update delete" ;;
    operation) echo "list get" ;;
    flowhook) echo "list get attach detach" ;;
    trace) echo "create list get data delete" ;;
    iam) echo "get set" ;;
    sync) echo "get add remove" ;;
    raw) echo "GET POST PUT DELETE" ;;
    cache) echo "list get create delete clear" ;;
    env) echo "list get create delete debugmask health export import" ;;
    virtualhost) echo "list get create update delete" ;;
    envgroup) echo "list get attachments attach" ;;
    instance) echo "list attachments attach" ;;
    stats) echo "traffic query" ;;
    server) echo "list get env-servers org-servers ips names attach detach health" ;;
    report) echo "list get" ;;
    user) echo "list create delete roles" ;;
    org) echo "get delete" ;;
    token) echo "print header" ;;
    sa) echo "create status undo" ;;
    profile) echo "list use show current clear" ;;
  esac
}

_apigee_verb_opts() { # resource verb
  case "$1 $2" in
    "env export") echo "--no-targetservers --no-kvms --no-keystores --no-developers --no-products --no-apps --no-bundles --kvm-format --show-credentials --out" ;;
    "env import") echo "--no-targetservers --no-kvms --no-developers --no-products --no-apps --no-bundles --deploy --existing-revisions --service-account --service-account-from --overwrite --allow-masked" ;;
    "kvm import") echo "--overwrite --allow-masked --format" ;;
    "kvm export") echo "--format --out" ;;
    "proxy compare" | "sharedflow compare") echo "--dir" ;;
    "proxy stale" | "sharedflow stale") echo "--include-undeployed" ;;
    "app create" | "developer create") echo "--developer --first --last --user --attr --from-file --product --callback" ;;
    "app delete") echo "--developer --prefix" ;;
    "cache create") echo "--description --timeout --max-elements --max-elements-disk --size-kb --disk-mb --overflow-to-disk --persistent" ;;
    "virtualhost create" | "virtualhost update") echo "--port --alias --keystore --key-alias --from-file" ;;
    *" upload-cert") echo "--alias --cert-file --key-file" ;;
    "product create") echo "--proxy --environment --scope --display-name --description --approval --quota --quota-interval --quota-unit" ;;
    "product find") echo "--proxy" ;;
    "flowhook attach") echo "--sharedflow --continue-on-error --description" ;;
    "trace create") echo "--session --timeout --filter" ;;
    "iam get" | "iam set") echo "--scope --from-file" ;;
    "keystore self-signed" | "truststore self-signed") echo "--alias --common-name --days --key-size --org-name --country" ;;
    "proxy export" | "sharedflow export") echo "--dir" ;;
    "stats traffic") echo "--by --select --time-unit" ;;
    "stats query") echo "--select --range --filter --limit --time-unit --sort --sortby" ;;
    "proxy deploy" | "sharedflow deploy") echo "--latest --service-account" ;;
    "proxy clean-revisions" | "sharedflow clean-revisions") echo "--all --keep" ;;
    *) echo "--help" ;;
  esac
}

_apigee_profiles() {
  local d f cfg="${APIGEE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/apigee-toolkit}"
  local bin home
  bin="$(command -v apigee 2>/dev/null)" && home="$(cd "$(dirname "$(readlink -f "$bin" 2>/dev/null || echo "$bin")")/.." 2>/dev/null && pwd)"
  for d in "$cfg/profiles" "${home:+$home/config/profiles}"; do
    [[ -n "$d" && -d "$d" ]] || continue
    for f in "$d"/*.env; do
      [[ -f "$f" ]] && basename "$f" .env
    done
  done
}

_apigee() {
  local cur="${COMP_WORDS[COMP_CWORD]}" prev=""
  ((COMP_CWORD > 0)) && prev="${COMP_WORDS[COMP_CWORD - 1]}"
  COMPREPLY=()

  # values of global options
  case "$prev" in
    --platform) mapfile -t COMPREPLY < <(compgen -W "x hybrid edge opdk" -- "$cur"); return 0 ;;
    --json-engine) mapfile -t COMPREPLY < <(compgen -W "jq python" -- "$cur"); return 0 ;;
    --profile) mapfile -t COMPREPLY < <(compgen -W "$(_apigee_profiles)" -- "$cur"); return 0 ;;
    --org | --env | --service-account | --service-account-from | --kvm-format | --format | --keep) return 0 ;;
    --out | --dir) mapfile -t COMPREPLY < <(compgen -d -- "$cur"); return 0 ;;
  esac

  # locate resource and verb, skipping global options and their values
  local i w resource="" verb="" rpos=0
  for ((i = 1; i < COMP_CWORD; i++)); do
    w="${COMP_WORDS[i]}"
    case "$w" in
      --platform | --org | --env | --profile | --json-engine) ((i++)); continue ;;
      -*) continue ;;
    esac
    if [[ -z "$resource" ]]; then
      resource="$(_apigee_canon "$w")"
      rpos=$i
    elif [[ -z "$verb" ]]; then
      verb="$w"
      break
    fi
  done

  if [[ -z "$resource" ]]; then
    if [[ "$cur" == -* ]]; then
      mapfile -t COMPREPLY < <(compgen -W "$_apigee_global_opts" -- "$cur")
    else
      mapfile -t COMPREPLY < <(compgen -W "$_apigee_resources $_apigee_aliases" -- "$cur")
    fi
    return 0
  fi

  if [[ -z "$verb" ]]; then
    if [[ "$cur" == -* ]]; then
      mapfile -t COMPREPLY < <(compgen -W "$_apigee_global_opts" -- "$cur")
    else
      mapfile -t COMPREPLY < <(compgen -W "$(_apigee_verbs_for "$resource")" -- "$cur")
    fi
    return 0
  fi

  # after the verb
  if [[ "$resource" == profile && "$verb" == use && "$cur" != -* ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$(_apigee_profiles)" -- "$cur")
    return 0
  fi
  if [[ "$cur" == -* ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$(_apigee_verb_opts "$resource" "$verb") $_apigee_global_opts" -- "$cur")
  else
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
  fi
  return 0
}

complete -o default -F _apigee apigee
