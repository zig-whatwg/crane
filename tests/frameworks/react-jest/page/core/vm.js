'use strict';

// Node's vm in the browser page. Jest compiles every module of the test with vm.compileFunction in
// its environment's context; under jsdom that context is jsdom's window, here it is the page itself
// (jsdom-environment.js: getInternalVMContext() answers `pageContext`). A function compiled here is the
// same function Node's compileFunction makes: the code is its body, its parameters the ones given, and
// its frames name the file (//# sourceURL, the absolute path, as Node's frames do).

const {native} = __reactJestPage;
const pageContext = Object.freeze({__proto__: null, description: 'the browser page'});

function withSource(code, filename) {
  return filename ? code + '\n//# sourceURL=' + filename : code;
}
function check(context) {
  if (context !== undefined && context !== pageContext) {
    throw new TypeError('The browser page has one context: the page itself');
  }
}

// The function's frames read `Object.<anonymous>`, as a function from Node's compileFunction called
// on module.exports does (React's tests compare stack frames: ReactUse's callStack, Flight's debug
// stacks). V8 names an anonymous function in eval'd code "eval"; a function named
// "Object.<anonymous>" prints as that, Jest's own wrapper before compileFunction.
function compileFunction(code, params = [], options = {}) {
  check(options.parsingContext);
  return (0, native.eval)(withSource('({"Object.<anonymous>": function (' + params.join(', ') + ') {' + code + '\n}})["Object.<anonymous>"]', options.filename));
}

function runInContext(code, context, options) {
  check(context);
  const filename = typeof options === 'string' ? options : options && options.filename;
  return (0, native.eval)(withSource(code, filename));
}

class Script {
  constructor(code, options) {
    this.code = String(code);
    this.filename = typeof options === 'string' ? options : options && options.filename;
  }
  runInContext(context) {
    return runInContext(this.code, context, {filename: this.filename});
  }
  runInThisContext() {
    return runInContext(this.code, undefined, {filename: this.filename});
  }
  runInNewContext() {
    throw new Error('vm: a new context is not available in the browser page');
  }
  createCachedData() {
    return new Uint8Array(0);
  }
}

module.exports = {
  pageContext,
  compileFunction,
  runInContext,
  runInThisContext: (code, options) => runInContext(code, undefined, options),
  runInNewContext() {
    throw new Error('vm: a new context is not available in the browser page');
  },
  createContext(o) {
    if (o === pageContext) return o;
    throw new Error('vm: a new context is not available in the browser page');
  },
  isContext: o => o === pageContext,
  Script,
  constants: {USE_MAIN_CONTEXT_DEFAULT_LOADER: Symbol('vm_dynamic_import_main_context_default'), DONT_CONTEXTIFY: Symbol('vm_context_no_contextify')},
};
