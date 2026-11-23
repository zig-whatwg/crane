'use strict';

// Node's crypto in the browser page: the browser's Web Crypto random sources. Hashing (createHash)
// has no synchronous browser equivalent, so it fails and says so.

const {native} = __reactJestPage;

function unavailable(name) {
  return () => {
    throw new Error(`crypto.${name} is not available in the browser page`);
  };
}

module.exports = {
  webcrypto: native.crypto,
  subtle: native.crypto.subtle,
  getRandomValues: a => native.crypto.getRandomValues(a),
  randomUUID: () => native.crypto.randomUUID(),
  randomBytes(n) {
    const {Buffer} = require('buffer');
    return Buffer.from(native.crypto.getRandomValues(new Uint8Array(n)));
  },
  createHash: unavailable('createHash'),
  createHmac: unavailable('createHmac'),
};
