const fs = require('fs');
const jose = require('node-jose');

const args = process.argv.slice(2);

const publicKey = fs.readFileSync(args[0]);
const hash = args[1] || 'SHA-256';

(async () => {
  const key = await jose.JWK.asKey(publicKey, 'pem');
  key.thumbprint(hash).
    then(function(print) {
      console.log(jose.util.base64url.encode(print));
    });
})();
