'use strict';

// Node's perf_hooks in the browser page: the browser's own performance.

const {native} = __reactJestPage;

module.exports = {performance: native.performance, PerformanceObserver: globalThis.PerformanceObserver, constants: {}};
