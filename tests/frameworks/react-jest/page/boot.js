// React's own Jest suite with a browser page in jsdom's place: the page's half (README.md).
//
// The page at http://localhost/ is jsdom's document in Jest's environment: '<!DOCTYPE html>' with an
// empty head and body (this script removes itself before anything else runs). The console - or, for
// the Chrome column, Playwright - calls __reactJest.run(<test file>, <run id>), and the page then does
// what a Jest worker does for one file: Jest's own modules, from React's node_modules, loaded as Node
// loads CommonJS (this file's loader), run the file with React's own environment class - in which the
// `jsdom` package is this page itself (jsdom-environment.js) - and the result goes back to the server.
//
// Outside the test, Jest's code sees Node's free variables (process, Buffer, global, setImmediate) as
// module-wrapper arguments, never as page globals; Node's core modules are the stand-ins the server
// names (server.mjs coreShims). What only Node can answer - resolution, React's transform, the
// checkout's files - is asked over synchronous XMLHttpRequest, so require() stays synchronous.
(() => {
  'use strict';
  const boot = document.currentScript;
  // The browser's own primitives, captured before a test can fake or replace them (React's tests
  // patch MessageChannel, setTimeout, setImmediate; Jest's fake timers replace the timers).
  const native = {
    setTimeout: globalThis.setTimeout.bind(globalThis),
    clearTimeout: globalThis.clearTimeout.bind(globalThis),
    setInterval: globalThis.setInterval.bind(globalThis),
    clearInterval: globalThis.clearInterval.bind(globalThis),
    queueMicrotask: globalThis.queueMicrotask.bind(globalThis),
    MessageChannel: globalThis.MessageChannel,
    MessagePort: globalThis.MessagePort,
    BroadcastChannel: globalThis.BroadcastChannel,
    XMLHttpRequest: globalThis.XMLHttpRequest,
    fetch: globalThis.fetch.bind(globalThis),
    TextEncoder: globalThis.TextEncoder,
    TextDecoder: globalThis.TextDecoder,
    performance: globalThis.performance,
    console: globalThis.console,
    consoleLog: globalThis.console.log.bind(globalThis.console),
    consoleError: globalThis.console.error.bind(globalThis.console),
    URL: globalThis.URL,
    URLSearchParams: globalThis.URLSearchParams,
    crypto: globalThis.crypto,
    eval: globalThis.eval,
    JSON: globalThis.JSON,
    Promise: globalThis.Promise,
    Date: globalThis.Date,
    AbortController: globalThis.AbortController,
    webStreams: {
      ReadableStream: globalThis.ReadableStream,
      ReadableStreamDefaultReader: globalThis.ReadableStreamDefaultReader,
      ReadableStreamBYOBReader: globalThis.ReadableStreamBYOBReader,
      ReadableStreamDefaultController: globalThis.ReadableStreamDefaultController,
      ReadableByteStreamController: globalThis.ReadableByteStreamController,
      WritableStream: globalThis.WritableStream,
      WritableStreamDefaultWriter: globalThis.WritableStreamDefaultWriter,
      WritableStreamDefaultController: globalThis.WritableStreamDefaultController,
      TransformStream: globalThis.TransformStream,
      TransformStreamDefaultController: globalThis.TransformStreamDefaultController,
      ByteLengthQueuingStrategy: globalThis.ByteLengthQueuingStrategy,
      CountQueuingStrategy: globalThis.CountQueuingStrategy,
      TextEncoderStream: globalThis.TextEncoderStream,
      TextDecoderStream: globalThis.TextDecoderStream,
      CompressionStream: globalThis.CompressionStream,
      DecompressionStream: globalThis.DecompressionStream,
    },
  };
  boot.remove();

  let runId = null;
  let session = null;

  // --- the server ---------------------------------------------------------------------------------
  function encode(value) {
    return native.JSON.stringify(value, (_k, v) => {
      if (v instanceof Map) return {__map: [...v]};
      if (v instanceof Set) return {__set: [...v]};
      if (v === undefined) return {__undefined: true};
      if (typeof v === 'function') return undefined;
      return v;
    });
  }
  // Every question the page asks the server has one answer for the whole run (the checkout, the
  // resolver's maps and the transform do not change), so each is asked once. The server sends, with an
  // answer, the answers it can tell the page will ask next - for a module, the resolution, mock lookup
  // and transform of each module it requires, and theirs (server.mjs prefetch) - so a file costs tens of
  // round trips instead of thousands. A key is the route and the body as encode() writes it.
  const answers = new Map();
  const callStats = new Map();
  function call(route, body) {
    const key = route + '\0' + encode(body);
    let out = answers.get(key);
    const st = callStats.get(route) || {n: 0, asked: 0, ms: 0};
    st.n++;
    if (out === undefined) {
      const t0 = native.performance.now();
      const xhr = new native.XMLHttpRequest();
      xhr.open('POST', '/__react_jest/' + route, false);
      xhr.setRequestHeader('content-type', 'application/json');
      if (runId) xhr.setRequestHeader('x-react-jest-run', runId);
      xhr.send(encode(body));
      if (xhr.status !== 200) throw new Error(`react-jest server: ${route} answered ${xhr.status}`);
      out = native.JSON.parse(xhr.responseText);
      if (out.prefetch) {
        for (const [k, v] of out.prefetch) if (!answers.has(k)) answers.set(k, v);
        delete out.prefetch;
      }
      answers.set(key, out);
      st.asked++;
      st.ms += native.performance.now() - t0;
    }
    callStats.set(route, st);
    if (out.error) throw revive(out.error);
    return out;
  }
  function revive(e) {
    const error = new Error(e.message);
    for (const k of Object.keys(e)) if (k !== 'message' && k !== 'stack' && k !== 'name') error[k] = e[k];
    return error;
  }
  // Not `keepalive`: a keepalive request's body is limited to 64 KiB, and a file's result is larger.
  function postAsync(route, body) {
    return native.fetch('/__react_jest/' + route, {method: 'POST', headers: {'content-type': 'application/json'}, body: encode(body)});
  }
  function log(line) {
    postAsync('log', {runId, line: String(line)}).catch(() => {});
  }

  // --- Node's CommonJS loader, for the modules outside the test --------------------------------------
  const modules = new Map(); // filename -> module
  const resolutions = new Map();
  const coreCache = new Map();

  function dirname(p) {
    const i = p.lastIndexOf('/');
    return i <= 0 ? '/' : p.slice(0, i);
  }

  function resolveFrom(dir, request) {
    const key = dir + '\0' + request;
    let r = resolutions.get(key);
    if (!r) {
      r = call('node-resolve', {from: dir, request});
      resolutions.set(key, r);
    }
    return r;
  }

  function makeRequire(filename, parent) {
    const dir = dirname(filename);
    const require = function require(request) {
      const r = resolveFrom(dir, request);
      return r.core !== undefined ? core(r.core) : load(r.path, parent);
    };
    require.resolve = function resolve(request) {
      const r = resolveFrom(dir, request);
      return r.core !== undefined ? r.core : r.path;
    };
    require.resolve.paths = () => [];
    require.cache = cacheView;
    require.main = undefined;
    require.extensions = {'.js': null, '.json': null, '.node': null};
    return require;
  }
  const cacheView = new Proxy({}, {
    get: (_t, k) => (typeof k === 'string' ? modules.get(k) : undefined),
    has: (_t, k) => modules.has(k),
    deleteProperty: (_t, k) => modules.delete(k),
    ownKeys: () => [...modules.keys()],
    getOwnPropertyDescriptor: (_t, k) => (modules.has(k) ? {value: modules.get(k), enumerable: true, configurable: true} : undefined),
  });

  // Node's wrapper. Node's free variables (process, Buffer, global, setImmediate, clearImmediate) are
  // an enclosing function's parameters, not the wrapper's, so a module may still declare its own
  // `const Buffer` as it may in Node. __reactJestPage is the page's own API for the harness's
  // stand-ins (page/core/*.js); no other module names it. The source URL is the file's absolute path,
  // as in Node's stack frames (and Jest's filtering of them).
  // The module function is named "Object.<anonymous>" so its frames read as Node's do (page/core/vm.js).
  const wrapperHead =
    '(function (process, Buffer, global, setImmediate, clearImmediate, __reactJestPage) { return {"Object.<anonymous>": function (exports, require, module, __filename, __dirname) {';
  function compile(code, filename) {
    return (0, native.eval)(wrapperHead + code + '\n}}["Object.<anonymous>"]; })\n//# sourceURL=' + filename);
  }

  function load(filename, parent) {
    const cached = modules.get(filename);
    if (cached) return cached.exports;
    const module = {id: filename, filename, path: dirname(filename), exports: {}, loaded: false, parent, children: [], paths: []};
    module.require = makeRequire(filename, module);
    modules.set(filename, module);
    try {
      const src = call('outer-source', {path: filename});
      if (src.json !== undefined) {
        module.exports = native.JSON.parse(src.json);
      } else {
        const fn = compile(src.code, filename)(proc, nodeGlobals.Buffer, globalThis, nodeGlobals.setImmediate, nodeGlobals.clearImmediate, pageApi);
        fn.call(module.exports, module.exports, module.require, module, filename, module.path);
      }
      module.loaded = true;
    } catch (e) {
      modules.delete(filename);
      throw e;
    }
    if (parent) parent.children.push(module);
    return module.exports;
  }

  // --- Node's core modules ------------------------------------------------------------------------
  function core(name) {
    if (name === 'process') return proc;
    if (coreCache.has(name)) return coreCache.get(name);
    const shim = session.coreShims[name];
    if (!shim) {
      const e = new Error(`Cannot find module '${name}': Node's ${name} module has no stand-in in the browser page (tests/frameworks/react-jest)`);
      e.code = 'MODULE_NOT_FOUND';
      throw e;
    }
    const m = load(shim, null);
    coreCache.set(name, m);
    return m;
  }

  // Node's setImmediate: a task after the current one (a MessageChannel message), the browser's
  // nearest; never a fake timer.
  const immediates = new Map();
  let nextImmediate = 1;
  const immediateChannel = new native.MessageChannel();
  const immediateQueue = [];
  immediateChannel.port1.onmessage = () => {
    const entry = immediateQueue.shift();
    if (entry && immediates.has(entry.id)) {
      immediates.delete(entry.id);
      entry.fn(...entry.args);
    }
  };
  const nodeGlobals = {
    setImmediate(fn, ...args) {
      const id = nextImmediate++;
      const handle = {id, ref() { return handle; }, unref() { return handle; }, hasRef: () => true, [Symbol.toPrimitive]: () => id};
      immediates.set(id, true);
      immediateQueue.push({id, fn, args});
      immediateChannel.port2.postMessage(null);
      return handle;
    },
    clearImmediate(handle) {
      if (handle) immediates.delete(typeof handle === 'object' ? handle.id : handle);
    },
    Buffer: undefined, // set once `buffer` loads (below)
  };

  const pageApi = {
    native,
    call,
    log,
    nodeGlobals,
    makeRequire: filename => makeRequire(filename, null),
    runNodeModule(module, content, filename) {
      module.filename = filename;
      module.id = module.id || filename;
      module.path = dirname(filename);
      module.require = makeRequire(filename, module);
      const fn = compile(content, filename)(proc, nodeGlobals.Buffer, globalThis, nodeGlobals.setImmediate, nodeGlobals.clearImmediate, pageApi);
      fn.call(module.exports, module.exports, module.require, module, filename, module.path);
      module.loaded = true;
    },
    get session() {
      return session;
    },
  };

  // --- process: the Jest worker's, as far as a page can have it -----------------------------------
  let proc = null;
  function makeProcess(EventEmitter) {
    // As in Node, the prototype's constructor is a plain function (jest-util's createProcessObject
    // calls each constructor up the chain on its copy), over EventEmitter's prototype.
    const Process = function process() {};
    Process.prototype = Object.create(EventEmitter.prototype, {constructor: {value: Process, writable: true, configurable: true}});
    const p = new Process();
    EventEmitter.call(p);
    const start = native.performance.now();
    Object.assign(p, {
      title: 'node',
      version: session.version,
      versions: {...session.versions},
      arch: session.arch,
      platform: session.platform,
      release: {name: 'node'},
      argv: ['/usr/local/bin/node', session.reactRoot + '/node_modules/jest-worker/build/processChild.js'],
      execArgv: [],
      execPath: '/usr/local/bin/node',
      env: {...session.env},
      pid: session.pid,
      ppid: 1,
      exitCode: undefined,
      features: {inspector: false, debug: false, uv: true, ipv6: true, tls_alpn: true, tls_sni: true, tls_ocsp: true, tls: true, cached_builtins: true, require_module: false, typescript: false},
      config: {variables: {}},
      cwd: () => session.cwd,
      chdir() { throw new Error('process.chdir() is not supported in the browser page'); },
      umask: () => 0o22,
      getuid: () => 501,
      getgid: () => 20,
      geteuid: () => 501,
      getegid: () => 20,
      uptime: () => (native.performance.now() - start) / 1000,
      cpuUsage: () => ({user: 0, system: 0}),
      memoryUsage: Object.assign(() => ({rss: 0, heapTotal: 0, heapUsed: 0, external: 0, arrayBuffers: 0}), {rss: () => 0}),
      resourceUsage: () => ({}),
      emitWarning(warning) { native.console.warn(String(warning && warning.message || warning)); },
      binding(name) { throw new Error(`process.binding('${name}') is not supported in the browser page`); },
      exit(code) { throw new Error(`process.exit(${code === undefined ? '' : code}) called in the browser page`); },
      abort() { throw new Error('process.abort() called in the browser page'); },
      kill() { throw new Error('process.kill() is not supported in the browser page'); },
      nextTick(fn, ...a) { native.queueMicrotask(() => fn(...a)); },
      stdout: {write(s) { native.consoleLog(String(s).replace(/\n$/, '')); return true; }, isTTY: false, columns: 80, rows: 24, fd: 1, on() { return this; }, once() { return this; }, end() {}},
      stderr: {write(s) { native.consoleError(String(s).replace(/\n$/, '')); return true; }, isTTY: false, columns: 80, rows: 24, fd: 2, on() { return this; }, once() { return this; }, end() {}},
      stdin: {isTTY: false, fd: 0, on() { return this; }, once() { return this; }},
    });
    const hrtime = prev => {
      const ns = BigInt(Math.round(native.performance.now() * 1e6));
      const now = [Number(ns / 1000000000n), Number(ns % 1000000000n)];
      if (!prev) return now;
      let s = now[0] - prev[0];
      let n = now[1] - prev[1];
      if (n < 0) { s -= 1; n += 1e9; }
      return [s, n];
    };
    hrtime.bigint = () => BigInt(Math.round(native.performance.now() * 1e6));
    p.hrtime = hrtime;
    return p;
  }

  // Jest's parent-process events, from the browser's: an uncaught exception is the window's error
  // event (jest-environment-jsdom's own listener forwards it, as it does under jsdom), an unhandled
  // rejection the window's unhandledrejection, a late handler rejectionhandled.
  function forwardRejections() {
    globalThis.addEventListener('unhandledrejection', event => {
      proc.emit('unhandledRejection', event.reason, event.promise);
    });
    globalThis.addEventListener('rejectionhandled', event => {
      proc.emit('rejectionHandled', event.promise);
    });
  }

  async function run(testPath, id) {
    delete globalThis.__reactJest;
    runId = id;
    try {
      session = await (await native.fetch('/__react_jest/session')).json();
      const EventEmitter = load(session.coreShims.events, null);
      proc = makeProcess(EventEmitter.EventEmitter || EventEmitter);
      nodeGlobals.Buffer = core('buffer').Buffer;
      forwardRejections();
      const runTest = load(session.harnessDir + '/page/run-test.js', null);
      const result = await runTest({
        testPath,
        session,
        call,
        log,
        native,
        proc,
        nodeGlobals,
        outerLoad: (p, options) => (options && options.transpile ? load(p, null) : load(p, null)),
        fromReact: request => {
          const r = resolveFrom(session.reactRoot, request);
          return r.core !== undefined ? core(r.core) : load(r.path, null);
        },
        resolveFromReact: request => resolveFrom(session.reactRoot, request).path,
        postCase: body => postAsync('case', {runId, ...body}).catch(() => {}),
        postResult: result => postAsync('result', {runId, result}),
      });
      log('calls: ' + [...callStats].map(([r, st]) => `${r} ${st.n} (${st.asked} asked, ${Math.round(st.ms)} ms)`).join(', '));
      return result ? 'finished' : 'no result';
    } catch (e) {
      log('run failed: ' + (e && e.stack || e));
      throw e;
    }
  }

  globalThis.__reactJest = {run};
})();
