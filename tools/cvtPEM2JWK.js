#!/usr/bin/env node
// Print the base64url JWK thumbprint (RFC 7638) of a PEM public key.
//
//   node tools/cvtPEM2JWK.js public.pem [SHA-256|SHA-1]
//
// Requires node-jose: npm --prefix tools install
const fs = require('fs');
const jose = require('node-jose');

const [pemPath, hash = 'SHA-256'] = process.argv.slice(2);
if (!pemPath) {
  console.error('usage: cvtPEM2JWK.js public.pem [SHA-256|SHA-1]');
  process.exit(2);
}

(async () => {
  const key = await jose.JWK.asKey(fs.readFileSync(pemPath), 'pem');
  const print = await key.thumbprint(hash);
  console.log(jose.util.base64url.encode(print));
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
