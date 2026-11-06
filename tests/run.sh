#!/usr/bin/env bash
#
# Run every tests/test_*.sh with each available JSON engine (jq, python).
#   tests/run.sh [test_file...]
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

files=("$@")
if ((${#files[@]} == 0)); then
  files=(test_*.sh)
fi
engines=""
command -v jq >/dev/null 2>&1 && engines="$engines jq"
command -v python3 >/dev/null 2>&1 && engines="$engines python"

rc=0
for engine in $engines; do
  printf '== JSON engine: %s\n' "$engine"
  for f in "${files[@]}"; do
    APIGEE_JSON_ENGINE="$engine" bash "$f" || rc=1
  done
done
if [[ "$rc" == 0 ]]; then printf 'ALL TESTS PASSED\n'; else printf 'SOME TESTS FAILED\n'; fi
exit "$rc"
