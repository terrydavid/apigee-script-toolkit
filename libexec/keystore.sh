# shellcheck shell=bash
#
# apigee keystore|truststore <verb> — read-only views of environment keystores.
# Apigee stores truststores as keystores that hold only certificates, so both
# resources use the same API; truststore get also shows each alias's certs.

keystore_verbs() { printf '%s\n' list get; }
truststore_verbs() { printf '%s\n' list get; }

keystore_help() { keystore_help_for keystore "${1:-}"; }
truststore_help() { keystore_help_for truststore "${1:-}"; }

keystore_help_for() {
  local label="$1"
  case "${2:-}" in
    "")
      cat <<EOF
Usage: apigee $label <verb>

Verbs:
  list         List keystores/truststores in --env
  get NAME     Show one $label$( [[ "$label" == truststore ]] && printf ' with alias certificate details')

Apigee models truststores as keystores containing only certificates, so the
list shows every keystore in the environment.
EOF
      ;;
    list) printf 'Usage: apigee %s list\n\nList keystore names in --env.\n' "$label" ;;
    get) printf 'Usage: apigee %s get NAME\n\nPrint the keystore JSON%s.\n' "$label" "$( [[ "$label" == truststore ]] && printf ', then each alias with its certificate info')" ;;
    *) apigee_die "unknown $label verb '$2' (see 'apigee $label --help')" ;;
  esac
}

keystore_path() {
  printf '%s/keystores%s\n' "$(apigee_env_path)" "${1:+/$(apigee_urlencode "$1")}"
}

keystore_run() {
  local label="$1" verb="${2:-}" name="${3:-}"
  case "$verb" in
    list)
      local body
      body="$(apigee_get "$(keystore_path)")" || exit 1
      printf '%s' "$body" | apigee_json names | sort
      ;;
    get)
      [[ -n "$name" ]] || apigee_die "missing NAME"
      local body alias
      body="$(apigee_get "$(keystore_path "$name")")" || exit 1
      printf '%s' "$body" | apigee_json pretty
      if [[ "$label" == truststore ]]; then
        for alias in $(printf '%s' "$body" | apigee_json names aliases); do
          apigee_get "$(keystore_path "$name")/aliases/$(apigee_urlencode "$alias")" | apigee_json pretty
        done
      fi
      ;;
    *) apigee_die "unknown $label verb '$verb' (see 'apigee $label --help')" ;;
  esac
}

keystore_main() { keystore_run keystore "$@"; }
truststore_main() { keystore_run truststore "$@"; }
