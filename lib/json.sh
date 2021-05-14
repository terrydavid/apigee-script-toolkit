#!/bin/sh

# `json.sh`, a pure-shell JSON parser.

set -e

# Load the `json` function and its friends.
. "$(dirname "$0")/json-lib.sh"

json
