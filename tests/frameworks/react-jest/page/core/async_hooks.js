'use strict';

// Node's async_hooks in the browser page. No browser has async context propagation (TC39's
// AsyncContext is a proposal), so AsyncLocalStorage here holds its store only for the synchronous
// extent of run(): what jest-circus uses it for (the name of a test.concurrent test, which React's
// tests never use). A test that needs the store across an await fails here, and says why.

class AsyncLocalStorage {
  constructor() {
    this._store = undefined;
  }
  getStore() {
    return this._store;
  }
  run(store, fn, ...args) {
    const prev = this._store;
    this._store = store;
    try {
      return fn(...args);
    } finally {
      this._store = prev;
    }
  }
  exit(fn, ...args) {
    return this.run(undefined, fn, ...args);
  }
  enterWith(store) {
    this._store = store;
  }
  disable() {
    this._store = undefined;
  }
  static bind(fn) {
    return fn;
  }
  static snapshot() {
    return (fn, ...args) => fn(...args);
  }
}

class AsyncResource {
  constructor(type) {
    this.type = type;
  }
  runInAsyncScope(fn, thisArg, ...args) {
    return fn.apply(thisArg, args);
  }
  emitDestroy() {
    return this;
  }
  asyncId() {
    return 1;
  }
  triggerAsyncId() {
    return 0;
  }
  bind(fn) {
    return fn;
  }
  static bind(fn) {
    return fn;
  }
}

module.exports = {
  AsyncLocalStorage,
  AsyncResource,
  createHook() {
    return {
      enable() {
        return this;
      },
      disable() {
        return this;
      },
    };
  },
  executionAsyncId: () => 1,
  triggerAsyncId: () => 0,
  executionAsyncResource: () => ({}),
  asyncWrapProviders: {},
};
