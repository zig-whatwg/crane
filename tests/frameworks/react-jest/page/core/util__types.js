'use strict';

// Node's util/types in the browser page: the npm `util` package's types, plus the checks it lacks.

const types = require('util/support/types');

function tag(v) {
  return Object.prototype.toString.call(v).slice(8, -1);
}

module.exports = Object.assign({}, types, {
  isNativeError: v => v instanceof Error || tag(v) === 'Error',
  isProxy: () => false,
  isExternal: () => false,
  isModuleNamespaceObject: v => tag(v) === 'Module',
  isKeyObject: () => false,
  isCryptoKey: v => typeof CryptoKey !== 'undefined' && v instanceof CryptoKey,
});
