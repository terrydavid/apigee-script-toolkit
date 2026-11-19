#!/usr/bin/env bash
#
# Add (or remove) bash completion for 'apigee' in your shell startup file.
#
#   setup/install-completion.sh                 append to ~/.bashrc
#   setup/install-completion.sh --zsh           append to ~/.zshrc (via bashcompinit)
#   setup/install-completion.sh --rc FILE       use another startup file
#   setup/install-completion.sh --uninstall     remove the block again
#
# Safe to re-run: the block is delimited by marker lines and added only once.
set -euo pipefail

HOME_DIR="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
RC="" ZSH=0 UNINSTALL=0
while (($#)); do
  case "$1" in
    --zsh) ZSH=1 ;;
    --rc) RC="${2:?--rc needs a FILE}"; shift ;;
    --uninstall) UNINSTALL=1 ;;
    -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'install-completion.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done
[[ -n "$RC" ]] || { if ((ZSH)); then RC="$HOME/.zshrc"; else RC="$HOME/.bashrc"; fi; }

BEGIN='# >>> apigee-toolkit completion >>>'
END='# <<< apigee-toolkit completion <<<'

remove_block() {
  [[ -f "$RC" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$RC" >"$tmp"
  cat "$tmp" >"$RC"
  rm -f "$tmp"
}

remove_block
if ((UNINSTALL)); then
  printf 'Removed apigee completion from %s\n' "$RC"
  exit 0
fi

{
  printf '%s\n' "$BEGIN"
  if ((ZSH)); then
    printf '%s\n' 'autoload -U +X bashcompinit && bashcompinit'
  fi
  printf 'source "%s/completions/apigee.bash"\n' "$HOME_DIR"
  printf '%s\n' "$END"
} >>"$RC"
printf 'Added apigee completion to %s. Open a new shell or run: source %s\n' "$RC" "$RC"
