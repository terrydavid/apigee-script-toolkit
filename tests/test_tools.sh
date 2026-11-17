#!/usr/bin/env bash
# tools/cvtPEM2JWK.js (needs node and `npm --prefix tools install`; skipped otherwise).
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

JWK="$ROOT/tools/cvtPEM2JWK.js"

have_jose() { command -v node >/dev/null 2>&1 && [[ -d "$ROOT/tools/node_modules/node-jose" ]]; }

skip() { printf '  skip %s (%s)\n' "$CURRENT" "$1"; }

test_thumbprint_matches_rfc7638() {
  have_jose || { skip "node-jose not installed"; return 0; }
  command -v openssl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || { skip "openssl or python3 missing"; return 0; }
  openssl genrsa -out "$T/k.pem" 2048 >/dev/null 2>&1
  openssl rsa -in "$T/k.pem" -pubout -out "$T/pub.pem" >/dev/null 2>&1
  run node "$JWK" "$T/pub.pem"
  assert_status "thumbprint" 0
  # RFC 7638: SHA-256 over {"e":..,"kty":"RSA","n":..}, base64url without padding.
  local n expect
  n="$(openssl rsa -pubin -in "$T/pub.pem" -noout -modulus | sed 's/Modulus=//')"
  expect="$(python3 -I -c '
import base64, hashlib, sys
n = int(sys.argv[1], 16)
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
nb = n.to_bytes((n.bit_length() + 7) // 8, "big")
doc = "{\"e\":\"AQAB\",\"kty\":\"RSA\",\"n\":\"%s\"}" % b64(nb)
print(b64(hashlib.sha256(doc.encode()).digest()))' "$n")"
  assert_eq "thumbprint value" "$expect" "$OUT"
}

test_usage_and_bad_input() {
  have_jose || { skip "node-jose not installed"; return 0; }
  run node "$JWK"
  assert_status "no args" 2
  printf 'not a key' >"$T/bad.pem"
  run node "$JWK" "$T/bad.pem"
  assert_status "bad pem" 1
}

run_tests
