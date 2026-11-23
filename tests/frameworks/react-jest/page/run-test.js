'use strict';

// One test file, as a Jest worker runs it: jest-runner's runTestInternal (jest-runner 30.4.2,
// build/index.js), step for step, in the page. What differs, and why:
// - the resolver and the transformer are the server's (jest-resolve's Resolver, @jest/transform's
//   ScriptTransformer with React's preprocessor) behind synchronous calls, because they read the disk
//   and run Babel; jest-runtime takes both as constructor arguments, so it runs unmodified;
// - the console stays the browser's: Jest's BufferedConsole only buffers output for its reporter, and
//   React's setup patches console methods on whatever console the global has;
// - the result is sent to the server, which aggregates it as Jest's parent process does.
// The test framework (jest-circus's runner), the environment (React's ReactJSDOMEnvironment over
// jest-environment-jsdom) and jest-runtime are Jest's and React's own files, loaded as Node loads them.

module.exports = async function runTest(ctx) {
  const {testPath, session, call, native, proc, fromReact, outerLoad, postCase, postResult, log} = ctx;
  const {projectConfig, globalConfig} = session;
  const fs = require('fs');
  const docblock = fromReact('jest-docblock');
  const {interopRequireDefault, setGlobal} = fromReact('jest-util');
  const {buildFailureTestResult} = fromReact('@jest/test-result');

  const testSource = fs.readFileSync(testPath, 'utf8');
  const docblockPragmas = docblock.parse(docblock.extract(testSource));
  // The server resolved the docblock's @jest-environment as jest-runner does (resolveTestEnvironment).
  const testEnvironment = session.testEnvironments[testPath];
  if (!testEnvironment) throw new Error(`${testPath}: not a file whose environment the page runs`);
  const cacheFS = new Map([[testPath, testSource]]);
  const transformer = makeTransformer(call);
  const resolver = makeResolver(call);
  // jest-runner: transformer.requireAndTranspileModule(testEnvironment / testRunner).
  const TestEnvironment = interopRequireDefault(outerLoad(testEnvironment, {transpile: true})).default;
  const testFramework = interopRequireDefault(outerLoad(projectConfig.testRunner, {transpile: true})).default;
  const Runtime = interopRequireDefault(fromReact('jest-runtime')).default;

  const testConsole = native.console;
  let extraTestEnvironmentOptions;
  const docblockEnvironmentOptions = docblockPragmas['jest-environment-options'];
  if (typeof docblockEnvironmentOptions === 'string') {
    extraTestEnvironmentOptions = JSON.parse(docblockEnvironmentOptions);
  }
  const loadTestEnvironmentStart = Date.now();
  const environment = new TestEnvironment(
    {
      globalConfig,
      projectConfig: extraTestEnvironmentOptions
        ? {...projectConfig, testEnvironmentOptions: {...projectConfig.testEnvironmentOptions, ...extraTestEnvironmentOptions}}
        : projectConfig,
    },
    {console: testConsole, docblockPragmas, testPath}
  );
  const loadTestEnvironmentEnd = Date.now();
  if (typeof environment.getVmContext !== 'function') {
    throw new Error(`Test environment found at "${testEnvironment}" does not export a "getVmContext" method`);
  }
  setGlobal(environment.global, 'console', testConsole, 'retain');
  const runtime = new Runtime(
    projectConfig,
    environment,
    resolver,
    transformer,
    cacheFS,
    {
      changedFiles: undefined,
      collectCoverage: globalConfig.collectCoverage,
      collectCoverageFrom: globalConfig.collectCoverageFrom,
      coverageProvider: globalConfig.coverageProvider,
      globalRootDir: globalConfig.rootDir,
      sourcesRelatedToTestsInChangedFiles: undefined,
    },
    testPath,
    globalConfig
  );

  const sourcemapSupport = outerLoad(session.sourceMapSupport);
  let isTornDown = false;
  const tearDownEnv = async () => {
    if (!isTornDown) {
      runtime.teardown();
      // source-map-support keeps memory leftovers in `Error.prepareStackTrace`
      require('vm').runInContext("Error.prepareStackTrace = () => '';", environment.getVmContext());
      sourcemapSupport.resetRetrieveHandlers();
      try {
        await environment.teardown();
      } finally {
        isTornDown = true;
      }
    }
  };

  const start = Date.now();
  const setupFilesStart = Date.now();
  for (const path of projectConfig.setupFiles) {
    const setupFile = runtime.requireModule(path);
    if (typeof setupFile === 'function') {
      await setupFile();
    }
  }
  const setupFilesEnd = Date.now();
  const sourcemapOptions = {
    environment: 'node',
    handleUncaughtExceptions: false,
    retrieveSourceMap: source => {
      const sourceMapSource = runtime.getSourceMaps()?.get(source);
      if (sourceMapSource) {
        try {
          return {map: JSON.parse(fs.readFileSync(sourceMapSource, 'utf8')), url: source};
        } catch {}
      }
      return null;
    },
  };
  // For tests
  runtime.requireInternalModule(session.sourceMapSupport).install(sourcemapOptions);
  // For runtime errors
  sourcemapSupport.install(sourcemapOptions);
  if (environment.global && environment.global.process && environment.global.process.exit) {
    const realExit = environment.global.process.exit;
    const {ErrorWithStack} = fromReact('jest-util');
    environment.global.process.exit = function exit(...args) {
      const error = new ErrorWithStack(`process.exit called with "${args.join(', ')}"`, exit);
      log(String(error.stack));
      return realExit(...args);
    };
  }
  Error.stackTraceLimit = 100;

  const sendMessageToJest = (eventName, args) => {
    postCase({eventName, args});
  };

  let result;
  try {
    await environment.setup();
    result = await testFramework(globalConfig, projectConfig, environment, runtime, testPath, sendMessageToJest);
    const testCount = result.numPassingTests + result.numFailingTests + result.numPendingTests + result.numTodoTests;
    const end = Date.now();
    const testRuntime = end - start;
    result.perfStats = {
      ...result.perfStats,
      end,
      loadTestEnvironmentEnd,
      loadTestEnvironmentStart,
      runtime: testRuntime,
      setupFilesEnd,
      setupFilesStart,
      slow: testRuntime / 1000 > projectConfig.slowTestThreshold,
      start,
    };
    result.testFilePath = testPath;
    result.console = undefined;
    result.skipped = testCount === result.numPendingTests;
    result.displayName = projectConfig.displayName;
  } catch (error) {
    // jest-runner's caller (runTest) turns a thrown error into Jest's failed-file result.
    result = buildFailureTestResult(testPath, error);
    result.testExecError = {message: String(error && error.message), stack: String(error && error.stack)};
  }
  // The result goes out before the environment's teardown: jest-environment-jsdom's teardown closes
  // the window (window.close()), which in a browser may end the page.
  await postResult(toJson(result));
  try {
    await tearDownEnv();
  } catch (e) {
    log('teardown failed: ' + (e && e.stack));
  }
  return result;
};

// What survives the trip to the server: plain data, errors as Jest's worker sends them (message and
// stack), anything else - a DOM node or event a matcher kept in failureDetails - as its description.
// A walk of its own, not JSON.stringify's: that reads `toJSON` from every object, and a DOM
// interface's toJSON on an object that only inherits from it throws.
function toJson(value) {
  const plain = new Set([Object.prototype, Array.prototype, null]);
  const seen = new WeakSet();
  const describe = v => {
    try {
      return Object.prototype.toString.call(v);
    } catch {
      return '[unserializable]';
    }
  };
  const walk = (v, depth) => {
    if (v === null || typeof v === 'string' || typeof v === 'boolean') return v;
    if (typeof v === 'number') return Number.isFinite(v) ? v : null;
    if (v === undefined || typeof v === 'function') return undefined;
    if (typeof v === 'bigint' || typeof v === 'symbol') return String(v);
    if (depth > 64) return '[too deep]';
    if (seen.has(v)) return '[Circular]';
    let proto;
    try {
      proto = Object.getPrototypeOf(v);
    } catch {
      return '[unserializable]';
    }
    if (v instanceof Error) {
      const o = {};
      for (const k of ['message', 'stack', 'name']) {
        try {
          o[k] = String(v[k]);
        } catch {}
      }
      for (const k of Object.keys(v)) {
        try {
          const x = v[k];
          o[k] = x !== null && typeof x === 'object' ? describe(x) : walk(x, depth + 1);
        } catch {}
      }
      return o;
    }
    if (!plain.has(proto)) return describe(v);
    seen.add(v);
    if (Array.isArray(v)) return v.map(x => {
      const w = walk(x, depth + 1);
      return w === undefined ? null : w;
    });
    const o = {};
    for (const k of Object.keys(v)) {
      let x;
      try {
        x = v[k];
      } catch {
        continue;
      }
      const w = walk(x, depth + 1);
      if (w !== undefined) o[k] = w;
    }
    return o;
  };
  return walk(value, 0);
}

// @jest/transform's ScriptTransformer, on the server. jest-runtime clears its own transform cache on
// resetModules; the answers do not change within a run, so the page keeps them.
function makeTransformer(call) {
  const transforms = new Map();
  const json = new Map();
  const key = (filename, options) => filename + '\0' + JSON.stringify(options || {});
  const transformer = {
    transform(filename, options) {
      const k = key(filename, options);
      let r = transforms.get(k);
      if (!r) {
        const out = call('transform', {filename, options});
        r = {code: out.code, sourceMapPath: out.sourceMapPath, originalCode: undefined};
        transforms.set(k, r);
      }
      return r;
    },
    async transformAsync(filename, options) {
      return transformer.transform(filename, options);
    },
    transformJson(filename, options) {
      const k = key(filename, options);
      let r = json.get(k);
      if (r === undefined) {
        r = call('transform', {filename, options, json: true}).value;
        json.set(k, r);
      }
      return r;
    },
    canTransformSync() {
      return true;
    },
  };
  return transformer;
}

// jest-resolve's Resolver, on the server: every method a call, every answer kept (they depend only
// on the arguments within a run).
function makeResolver(call) {
  const answers = new Map();
  return new Proxy(
    {},
    {
      get(_target, method) {
        if (typeof method !== 'string' || method === 'then') return undefined;
        return (...args) => {
          const k = method + '\0' + JSON.stringify(args, (_k, v) => (v instanceof Map ? {__map: [...v]} : v instanceof Set ? {__set: [...v]} : v === undefined ? {__undefined: true} : v));
          let a = answers.get(k);
          if (!a) {
            try {
              a = {ok: call('resolver', {method, args})};
            } catch (e) {
              a = {error: e};
            }
            answers.set(k, a);
          }
          if (a.error) throw a.error;
          return a.ok.undefined ? undefined : a.ok.value;
        };
      },
    }
  );
}
