'use strict';

// Node's crypto in the browser page: the browser's Web Crypto random sources, and Node's synchronous
// hashes (createHash: React Refresh's Babel plugin hashes hook signatures with sha1) from the pinned
// browser package create-hash, as browserify gives them. Web Crypto's digest is asynchronous only.

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
  createHash: algorithm => require('create-hash/browser')(algorithm),
  createHmac: unavailable('createHmac'),
};
