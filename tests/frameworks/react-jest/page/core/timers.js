'use strict';

// Node's timers in the browser page: the browser's own timers and the page's setImmediate, captured
// at page start. As in Node, the module's functions are the real ones even while a test's fake timers
// replace the globals (React's shared/enqueueTask asks this module for setImmediate for that reason).

const {native, nodeGlobals} = __reactJestPage;

module.exports = {
  setTimeout: native.setTimeout,
  clearTimeout: native.clearTimeout,
  setInterval: native.setInterval,
  clearInterval: native.clearInterval,
  setImmediate: nodeGlobals.setImmediate,
  clearImmediate: nodeGlobals.clearImmediate,
  promises: {
    setTimeout: (ms, value) => new native.Promise(resolve => native.setTimeout(() => resolve(value), ms)),
    setImmediate: value => new native.Promise(resolve => nodeGlobals.setImmediate(() => resolve(value))),
  },
};
