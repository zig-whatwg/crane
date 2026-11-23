// React's own Jest suite with a browser page in jsdom's place: the Node half (README.md).
//
// Node does what Jest does outside the test - and only that - with Jest's own code from React's own
// node_modules: jest-config reads React's config, `jest --listTests` selects the files, jest-runtime's
// createContext builds the haste map and jest-resolve's Resolver, @jest/transform's ScriptTransformer
// runs React's own preprocessor. The page (page/boot.js) runs the test the way a Jest worker runs it,
// with Jest's own runtime, runner and matchers, and asks this server - over synchronous XMLHttpRequest,
// so `require` stays synchronous as in Jest - for what only Node can answer: module resolution, the
// transform, and a read-only view of the checkout's files.
//
//   node server.mjs run --react=<React checkout> --browser=crane --console=<repl> --out=<dir>
//   node server.mjs run --react=<React checkout> --browser=chrome --chrome=<executable> --out=<dir>
//       [--files=<regexp>] [--parallel=<n>] [--file-timeout-ms=<ms>]
//   node server.mjs serve --react=<React checkout>          (the page at http://localhost/, by hand)
//
// The run writes <out>/jest.json, Jest's own `--json` shape (@jest/test-result's formatTestResults),
// <out>/files.txt (each file's outcome) and <out>/console/<n>.log (each browser's output).
//
// It must run under React's pinned Node (.nvmrc) with the variant's environment, as React's
// scripts/jest/jest-cli.js sets it for Jest: NODE_ENV, RELEASE_CHANNEL, and CI as GitHub Actions does.

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire, isBuiltin, builtinModules} from 'node:module';
import {spawn, spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const harnessDir = path.dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(3).map(a => {
    const m = /^--([^=]+)(?:=(.*))?$/.exec(a);
    if (!m) throw new Error(`unknown argument ${a}`);
    return [m[1], m[2] ?? 'true'];
  })
);
const command = process.argv[2];
if (command !== 'run' && command !== 'serve') {
  console.error('usage: node server.mjs run|serve --react=<dir> ...');
  process.exit(2);
}
const reactRoot = path.resolve(args.react ?? '.');
for (const name of ['NODE_ENV', 'RELEASE_CHANNEL']) {
  if (!process.env[name]) throw new Error(`${name} must be set as React's jest-cli.js sets it`);
}
// React's config reads process.cwd() as its rootDir (scripts/jest/config.base.js).
process.chdir(reactRoot);
// React's globalSetup (scripts/jest/setupGlobal.js) sets TZ for Jest's workers; the browsers get it
// from their process environment below.
process.env.TZ = 'UTC';
const reactRequire = createRequire(path.join(reactRoot, 'package.json'));
const harnessRequire = createRequire(path.join(harnessDir, 'package.json'));

// --- Jest's configuration, the files it selects, its resolver and transformer -----------------
const configPath = './scripts/jest/config.source.js';
const {readConfigs} = reactRequire('jest-config');
const {globalConfig, configs} = await readConfigs(
  {$0: 'jest', _: [], ci: true, config: configPath},
  [reactRoot]
);
if (configs.length !== 1) throw new Error(`expected one project, got ${configs.length}`);
// "Crane replaces jsdom": inside the test, the `jsdom` package is the browser's stand-in
// (page/jsdom.js), by Jest's own module-substitution mechanism. jsdom's deep paths stay real.
const projectConfig = {
  ...configs[0],
  moduleNameMapper: [...configs[0].moduleNameMapper, ['^jsdom$', path.join(harnessDir, 'page/jsdom.js')]],
};
const Runtime = reactRequire('jest-runtime').default;
const context = await Runtime.createContext(projectConfig, {maxWorkers: 1, watchman: false});
const resolver = context.resolver;
const {createScriptTransformer} = reactRequire('@jest/transform');
const transformer = await createScriptTransformer(projectConfig);
const jestDocblock = reactRequire('jest-docblock');
const {resolveTestEnvironment} = reactRequire('jest-resolve');
const testResult = reactRequire('@jest/test-result');
const {formatResultsErrors} = reactRequire('jest-message-util');

// The files Jest itself selects for this config: `jest --listTests`, React's own entry point.
function listTests() {
  const r = spawnSync(process.execPath, ['./scripts/jest/jest.js', '--config', configPath, '--ci', '--listTests', '--json'], {
    cwd: reactRoot,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  if (r.status !== 0) throw new Error(`jest --listTests failed: ${r.stderr}`);
  return JSON.parse(r.stdout).sort();
}

// The environment Jest's runner would build for a file (jest-runner runTestInternal: the docblock's
// @jest-environment, else the project's). Only the files that get React's jsdom environment run in the
// page; the others name theirs.
function environmentOf(testPath) {
  const pragmas = jestDocblock.parse(jestDocblock.extract(fs.readFileSync(testPath, 'utf8')));
  const custom = pragmas['jest-environment'];
  if (!custom) return projectConfig.testEnvironment;
  return resolveTestEnvironment({...projectConfig, requireResolveFunction: m => reactRequire.resolve(m), testEnvironment: custom});
}
const jsdomEnvironments = new Set([projectConfig.testEnvironment, reactRequire.resolve('jest-environment-jsdom')]);
const pageEnvironments = new Map(); // test path -> its environment, for the files the page runs

// --- what the page may ask -----------------------------------------------------------------------
// The page's stand-ins for Node's core modules: a browser package, or the harness's own module.
const coreShims = {
  assert: harnessRequire.resolve('assert/'),
  buffer: harnessRequire.resolve('buffer/'),
  events: harnessRequire.resolve('events/'),
  path: harnessRequire.resolve('path-browserify'),
  stream: harnessRequire.resolve('readable-stream'),
  string_decoder: harnessRequire.resolve('string_decoder/'),
};
for (const own of fs.readdirSync(path.join(harnessDir, 'page/core'))) {
  coreShims[own.replace(/\.js$/, '').replace(/__/g, '/')] = path.join(harnessDir, 'page/core', own);
}
// In the page, outside the test (Jest's own modules, the environment): `jsdom` is the page itself.
const outerSubstitutes = {jsdom: path.join(harnessDir, 'page/jsdom-environment.js')};

const readable = [reactRoot, harnessDir].map(d => d + path.sep);
function mayRead(p) {
  return readable.some(d => p.startsWith(d));
}

function fsCall({op, path: p, encoding}) {
  if (typeof p !== 'string' || !path.isAbsolute(p)) throw Object.assign(new Error(`bad path ${p}`), {code: 'EINVAL'});
  p = path.normalize(p);
  if (!mayRead(p)) throw Object.assign(new Error(`ENOENT: no such file or directory, ${op} '${p}'`), {code: 'ENOENT', errno: -2, syscall: op, path: p});
  switch (op) {
    case 'stat':
    case 'lstat': {
      const s = op === 'stat' ? fs.statSync(p) : fs.lstatSync(p);
      return {
        dev: s.dev, ino: s.ino, mode: s.mode, nlink: s.nlink, uid: s.uid, gid: s.gid, rdev: s.rdev, size: s.size,
        blksize: s.blksize, blocks: s.blocks, atimeMs: s.atimeMs, mtimeMs: s.mtimeMs, ctimeMs: s.ctimeMs,
        birthtimeMs: s.birthtimeMs, file: s.isFile(), directory: s.isDirectory(), symlink: s.isSymbolicLink(),
      };
    }
    case 'read':
      return encoding ? fs.readFileSync(p, encoding) : fs.readFileSync(p).toString('base64');
    case 'readdir':
      return fs.readdirSync(p, {withFileTypes: true}).map(d => ({name: d.name, file: d.isFile(), directory: d.isDirectory(), symlink: d.isSymbolicLink()}));
    case 'realpath':
      return fs.realpathSync(p);
    case 'readlink':
      return fs.readlinkSync(p);
    default:
      throw Object.assign(new Error(`EROFS: the page's file view is read-only, ${op} '${p}'`), {code: 'EROFS', syscall: op, path: p});
  }
}

// Node's own resolution, for the page's modules outside the test (Jest's code runs there as in Node).
function nodeResolve({from, request}) {
  const bare = request.startsWith('node:') ? request.slice(5) : request;
  if (outerSubstitutes[request]) return {path: outerSubstitutes[request]};
  if (isBuiltin(request) && !request.endsWith('/')) return {core: bare};
  return {path: createRequire(path.join(from, '__resolve__.js')).resolve(request)};
}

// A module outside the test: as jest-runner loads the environment and the test framework
// (ScriptTransformer.requireAndTranspileModule), files outside node_modules go through the project's
// transform; node_modules and the harness's own files run as they are.
const transformOptions = {
  instrument: false,
  supportsDynamicImport: false,
  supportsExportNamespaceFrom: false,
  supportsStaticESM: false,
  supportsTopLevelAwait: false,
};
function outerSource({path: p}) {
  if (!mayRead(p)) throw new Error(`not readable: ${p}`);
  if (p.endsWith('.json')) return {json: fs.readFileSync(p, 'utf8')};
  if (p.startsWith(harnessDir + path.sep) || p.includes(`${path.sep}node_modules${path.sep}`)) {
    return {code: fs.readFileSync(p, 'utf8')};
  }
  return {code: transformer.transform(p, transformOptions).code};
}

// Maps and Sets cross as tagged arrays (jest-runtime passes its virtual-mock Map to getModuleID).
function revive(_k, v) {
  if (v && typeof v === 'object' && !Array.isArray(v)) {
    if (Array.isArray(v.__map)) return new Map(v.__map);
    if (Array.isArray(v.__set)) return new Set(v.__set);
    if (v.__undefined === true) return undefined;
  }
  return v;
}
function resolverCall({method, args: a}) {
  if (typeof resolver[method] !== 'function' || method.startsWith('_')) throw new Error(`no resolver method ${method}`);
  const value = resolver[method](...a);
  return value === undefined ? {undefined: true} : {value};
}
function transformCall({filename, options, json}) {
  if (json) return {value: transformer.transformJson(filename, options, fs.readFileSync(filename, 'utf8'))};
  const r = transformer.transform(filename, options);
  return {code: r.code, sourceMapPath: r.sourceMapPath ?? null};
}

// --- answers, and the answers the page will ask for next -------------------------------------------
// Every question has one answer for the whole run, so answers are kept (across files too). With an
// answer the server sends what the page will ask next, keyed as page/boot.js keys its questions
// (route + encode(body)):
// - what an earlier file asked after this same question, in its order (a file's module loading is a
//   long sequence that most files share: React, React DOM, internal-test-utils, Jest's matchers), and
// - for a module outside the test, Node's resolution and source of each module it requires.
// A guess the page never asks for costs only bytes; a question the page asks differently is asked.
const answerable = new Set(['fs', 'node-resolve', 'outer-source', 'resolver', 'transform']);
const memo = new Map(); // key -> {answer, size}
function encodeKey(value) {
  return JSON.stringify(value, (_k, v) => {
    if (v instanceof Map) return {__map: [...v]};
    if (v instanceof Set) return {__set: [...v]};
    if (v === undefined) return {__undefined: true};
    if (typeof v === 'function') return undefined;
    return v;
  });
}
function answer(route, body, key = route + '\0' + encodeKey(body)) {
  const kept = memo.get(key);
  if (kept) return kept.answer;
  let out;
  try {
    switch (route) {
      case 'fs': out = {value: fsCall(body)}; break;
      case 'node-resolve': out = nodeResolve(body); break;
      case 'outer-source': out = outerSource(body); break;
      case 'resolver': out = resolverCall(body); break;
      case 'transform': out = transformCall(body); break;
    }
  } catch (e) {
    out = {error: errorJson(e)};
  }
  memo.set(key, {answer: out, size: key.length + JSON.stringify(out).length});
  return out;
}

const requirePattern = /\brequire\s*\(\s*(['"])([^'"\n\\]+)\1\s*\)/g;
function staticRequires(code) {
  const out = new Set();
  for (const m of code.matchAll(requirePattern)) out.add(m[2]);
  return out;
}
const prefetchBudget = 8 * 1024 * 1024;
const prefetchState = new Map(); // run id -> {sent: Set<key>, asked: key[]}
const firstAsked = new Map(); // key -> {asked: the asking run's key list, at: its index there}
function prefetchFor(run, route, body, out, key) {
  let state = prefetchState.get(run);
  if (!state) {
    state = {sent: new Set(), asked: []};
    prefetchState.set(run, state);
  }
  state.sent.add(key);
  const list = [];
  let bytes = 0;
  const push = k => {
    if (state.sent.has(k)) return;
    const kept = memo.get(k);
    if (!kept) return;
    state.sent.add(k);
    bytes += kept.size;
    list.push([k, kept.answer]);
  };
  const earlier = firstAsked.get(key);
  if (earlier) {
    for (let i = earlier.at + 1; i < earlier.asked.length && bytes < prefetchBudget; i++) push(earlier.asked[i]);
  } else {
    firstAsked.set(key, {asked: state.asked, at: state.asked.length});
  }
  state.asked.push(key);
  if (route === 'outer-source' && typeof out.code === 'string') {
    const queue = [[body.path, out.code]];
    const visited = new Set([body.path]);
    while (queue.length > 0 && bytes < prefetchBudget) {
      const [file, code] = queue.shift();
      for (const request of staticRequires(code)) {
        const rb = {from: path.dirname(file), request};
        const rk = 'node-resolve\0' + encodeKey(rb);
        const r = answer('node-resolve', rb, rk);
        push(rk);
        if (typeof r.path !== 'string' || visited.has(r.path)) continue;
        visited.add(r.path);
        const sb = {path: r.path};
        const sk = 'outer-source\0' + encodeKey(sb);
        const src = answer('outer-source', sb, sk);
        push(sk);
        if (typeof src.code === 'string') queue.push([r.path, src.code]);
      }
    }
  }
  return list;
}

const pageHtml = '<!DOCTYPE html><html><head><script src="/__react_jest/boot.js"></script></head><body></body></html>';

// --- runs -----------------------------------------------------------------------------------------
const runs = new Map(); // runId -> {testPath, result, cases, resolve}

function errorJson(e) {
  const out = {message: String(e && e.message), name: e && e.name, stack: e && e.stack};
  for (const k of ['code', 'errno', 'syscall', 'path', 'moduleName', 'hint', 'requireStack', 'siblingWithSimilarExtensionFound']) {
    if (e && e[k] !== undefined) out[k] = e[k];
  }
  return out;
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return Buffer.concat(chunks).toString('utf8');
}

let session = null;
function sessionJson() {
  if (session) return session;
  session = JSON.stringify({
    reactRoot,
    harnessDir,
    cwd: reactRoot,
    platform: process.platform,
    arch: process.arch,
    version: process.version,
    versions: process.versions,
    pid: process.pid,
    // The environment React's jest-cli.js gives Jest's workers (NODE_ENV, RELEASE_CHANNEL,
    // compactConsole), CI as GitHub Actions sets it, and TZ from React's globalSetup.
    env: {
      NODE_ENV: process.env.NODE_ENV,
      RELEASE_CHANNEL: process.env.RELEASE_CHANNEL,
      compactConsole: 'false',
      CI: process.env.CI ?? '',
      TZ: 'UTC',
      ...(process.env.VARIANT ? {VARIANT: process.env.VARIANT} : {}),
      HOME: '/nonexistent',
      PATH: '/usr/bin:/bin',
      JEST_WORKER_ID: '1',
    },
    coreShims,
    builtinModules,
    projectConfig,
    globalConfig,
    testRunner: projectConfig.testRunner,
    // Each file's environment, as jest-runner picks it (its @jest-environment docblock, else the
    // project's): React's ReactJSDOMEnvironment, or jest-environment-jsdom named as `jsdom`.
    testEnvironments: Object.fromEntries(pageEnvironments),
    sourceMapSupport: reactRequire.resolve('source-map-support', {paths: [path.dirname(reactRequire.resolve('jest-runner'))]}),
  });
  return session;
}

async function handle(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const send = (status, body, type = 'application/json') => {
    res.writeHead(status, {'content-type': type, 'cache-control': 'no-store'});
    res.end(body);
  };
  try {
    if (req.method === 'GET' && url.pathname === '/') return send(200, pageHtml, 'text/html; charset=utf-8');
    if (req.method === 'GET' && url.pathname === '/__react_jest/boot.js') {
      return send(200, fs.readFileSync(path.join(harnessDir, 'page/boot.js')), 'text/javascript; charset=utf-8');
    }
    if (req.method === 'GET' && url.pathname === '/__react_jest/session') return send(200, sessionJson());
    if (req.method === 'POST' && url.pathname.startsWith('/__react_jest/')) {
      const route = url.pathname.slice('/__react_jest/'.length);
      const text = await readBody(req);
      const body = JSON.parse(text, revive);
      let out;
      if (answerable.has(route)) {
        // The page keys a question by the very text it sends (page/boot.js call()).
        const key = route + '\0' + text;
        out = answer(route, body, key);
        const run = req.headers['x-react-jest-run'];
        if (run) {
          const prefetch = prefetchFor(run, route, body, out, key);
          if (prefetch.length > 0) out = {...out, prefetch};
        }
      } else {
        switch (route) {
          case 'case': {
            const r = runs.get(body.runId);
            if (r) r.cases.push(body);
            out = {};
            break;
          }
          case 'result': {
            const r = runs.get(body.runId);
            if (r && !r.result) {
              r.result = body.result;
              r.resolve();
            } else if (!r && command === 'serve') {
              // A probe browser's run (`serve`): its outcome on stdout, its result beside the others.
              const res = body.result;
              const failed = (res.testResults || []).filter(t => t.status === 'failed').map(t => t.fullName);
              const ua = req.headers['user-agent'] || '?';
              console.log(`PROBE ${ua} :: ${path.relative(reactRoot, res.testFilePath || '?')} :: ${res.numPassingTests} passed, ${res.numFailingTests} failed${res.testExecError ? ' (did not run: ' + res.testExecError.message + ')' : ''}`);
              for (const f of failed) console.log(`  FAILED ${f}`);
              if (args.out) {
                fs.mkdirSync(args.out, {recursive: true});
                fs.appendFileSync(path.join(args.out, 'probe-results.jsonl'), JSON.stringify({ua, result: res}) + '\n');
              }
            }
            out = {};
            break;
          }
          case 'log': {
            const r = runs.get(body.runId);
            console.log(`  [page ${r ? path.relative(reactRoot, r.testPath) : body.runId}] ${body.line}`);
            out = {};
            break;
          }
          default:
            return send(404, '{}');
        }
      }
      return send(200, JSON.stringify(out));
    }
    // Anything else the page asks for (an <img src>, a stylesheet) is not here.
    send(404, 'Not found', 'text/plain');
  } catch (e) {
    send(500, String(e && e.stack));
  }
}

// http://localhost/ is jsdom's URL in Jest's environment (jest-environment-jsdom: url
// 'http://localhost/'); React's tests read it (form.action, img.src). Port 80: macOS lets an
// unprivileged process bind a low port only on the wildcard address, so the server listens there
// and answers loopback connections only.
const loopback = new Set(['127.0.0.1', '::1', '::ffff:127.0.0.1']);
async function listen() {
  const s = http.createServer((req, res) => {
    if (!loopback.has(req.socket.remoteAddress)) {
      req.socket.destroy();
      return;
    }
    handle(req, res);
  });
  s.keepAliveTimeout = 60_000;
  await new Promise((resolve, reject) => {
    s.once('error', reject);
    s.listen({port: 80, host: '::', ipv6Only: false}, resolve);
  });
  return [s];
}

// --- the browsers --------------------------------------------------------------------------------
let nextRun = 1;
function startRun(testPath) {
  const runId = `${process.pid}-${nextRun++}`;
  let resolve;
  const done = new Promise(r => (resolve = r));
  const r = {runId, testPath, result: null, cases: [], log: [], resolve, done};
  runs.set(runId, r);
  return r;
}

// Crane: a fresh release console per file, as Jest gives each file a fresh environment; the page is
// opened the way a user opens it, and the run is started from the console the way a user types it.
async function runInCrane(r, logPath, timeoutMs) {
  const consolePath = args.console;
  const child = spawn(consolePath, ['http://localhost/', `--timeout=${Math.min(timeoutMs, 600_000)}`], {
    env: {...process.env, TZ: 'UTC'},
    stdio: ['pipe', 'pipe', 'pipe'],
    detached: true,
  });
  const log = fs.createWriteStream(logPath);
  child.stdout.pipe(log, {end: false});
  child.stderr.pipe(log, {end: false});
  child.stdin.end(`await __reactJest.run(${JSON.stringify(r.testPath)}, ${JSON.stringify(r.runId)})\n.exit\n`);
  const exited = new Promise(res => child.on('exit', (code, signal) => res({code, signal})));
  const timer = new Promise(res => setTimeout(() => res('timeout'), timeoutMs));
  const first = await Promise.race([r.done.then(() => 'result'), exited.then(e => ({exit: e})), timer]);
  let end = first;
  if (first === 'result') {
    // The page has answered; the console exits on `.exit`.
    end = await Promise.race([exited.then(e => ({exit: e})), new Promise(res => setTimeout(() => res('linger'), 30_000))]);
  }
  try { process.kill(-child.pid, 'SIGKILL'); } catch {}
  log.end();
  return {first, end};
}

// Chrome: the same page in a fresh browser context per file, driven over CDP by Playwright.
let chromeBrowser = null;
async function runInChrome(r, logPath, timeoutMs) {
  if (!chromeBrowser) {
    const {chromium} = harnessRequire('playwright-core');
    chromeBrowser = await chromium.launch({executablePath: args.chrome, headless: true, env: {...process.env, TZ: 'UTC'}});
  }
  const browserContext = await chromeBrowser.newContext();
  const page = await browserContext.newPage();
  const lines = [];
  page.on('console', m => lines.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', e => lines.push(`[pageerror] ${e.stack || e}`));
  let first;
  try {
    await page.goto('http://localhost/');
    const evaluation = page.evaluate(([f, id]) => __reactJest.run(f, id), [r.testPath, r.runId]).catch(e => lines.push(`[evaluate] ${e.message}`));
    first = await Promise.race([r.done.then(() => 'result'), evaluation.then(() => 'evaluated'), new Promise(res => setTimeout(() => res('timeout'), timeoutMs))]);
    if (first === 'evaluated') first = await Promise.race([r.done.then(() => 'result'), new Promise(res => setTimeout(() => res('no result'), 5_000))]);
  } finally {
    await browserContext.close().catch(() => {});
    fs.writeFileSync(logPath, lines.join('\n') + '\n');
  }
  return {first};
}

// A file the page never finished: Jest's own failed-file result, with the tests it did report.
function unfinished(r, why) {
  const failed = testResult.buildFailureTestResult(r.testPath, new Error(why));
  return failed;
}

async function run() {
  const all = listTests();
  const only = args.files ? new RegExp(args.files) : null;
  const selected = [];
  const skipped = [];
  for (const f of all) {
    if (only && !only.test(path.relative(reactRoot, f))) continue;
    const env = environmentOf(f);
    if (jsdomEnvironments.has(env)) {
      selected.push(f);
      pageEnvironments.set(f, env);
    }
    else skipped.push([f, env]);
  }
  const out = path.resolve(args.out);
  fs.mkdirSync(path.join(out, 'console'), {recursive: true});
  const servers = await listen();
  const parallel = Number(args.parallel ?? 3);
  const timeoutMs = Number(args['file-timeout-ms'] ?? 600_000);
  const browser = args.browser;
  if (browser !== 'crane' && browser !== 'chrome') throw new Error('--browser=crane|chrome');
  const aggregated = testResult.makeEmptyAggregatedTestResult();
  aggregated.startTime = Date.now();
  const outcomes = [];
  let index = 0;
  const started = Date.now();
  async function worker() {
    while (index < selected.length) {
      const i = index++;
      const testPath = selected[i];
      const r = startRun(testPath);
      const logPath = path.join(out, 'console', `${i}.log`);
      const t0 = Date.now();
      let outcome;
      try {
        outcome = browser === 'crane' ? await runInCrane(r, logPath, timeoutMs) : await runInChrome(r, logPath, timeoutMs);
      } catch (e) {
        outcome = {first: 'error', error: String(e && e.stack)};
      }
      let result = r.result;
      if (!result) {
        result = unfinished(r, `the page did not finish the file (${JSON.stringify(outcome)})`);
      }
      // As Jest's TestScheduler does before its reporters see the result.
      result.failureMessage = formatResultsErrors(result.testResults, projectConfig, globalConfig, testPath);
      testResult.addResult(aggregated, result);
      const rel = path.relative(reactRoot, testPath);
      const line = `${rel}\t${r.result ? 'finished' : 'UNFINISHED'}\t${result.numPassingTests}/${result.numFailingTests}/${result.numPendingTests}\t${Date.now() - t0}ms\tconsole/${i}.log\t${JSON.stringify(outcome)}`;
      outcomes.push(line);
      console.log(`[${outcomes.length}/${selected.length}] ${line}`);
      runs.delete(r.runId);
      prefetchState.delete(r.runId);
    }
  }
  // A warm-up file first, its result discarded: the server learns the sequence of questions a file's
  // module loading asks (prefetchFor), so the files after it load their modules in tens of round trips;
  // without it the first files of a run spend seconds of their first test's timeout loading React.
  if (selected.length > 0) {
    const r = startRun(selected[0]);
    const logPath = path.join(out, 'console', 'warm-up.log');
    try {
      await (browser === 'crane' ? runInCrane(r, logPath, timeoutMs) : runInChrome(r, logPath, timeoutMs));
    } catch {}
    runs.delete(r.runId);
    prefetchState.delete(r.runId);
    console.log(`warm-up ${path.relative(reactRoot, selected[0])}: ${r.result ? 'finished' : 'unfinished'} (not counted)`);
  }
  await Promise.all(Array.from({length: parallel}, worker));
  if (chromeBrowser) await chromeBrowser.close();
  for (const s of servers) s.close();
  aggregated.success = aggregated.numFailedTests === 0 && aggregated.numRuntimeErrorTestSuites === 0;
  const json = testResult.formatTestResults(aggregated);
  fs.writeFileSync(path.join(out, 'jest.json'), JSON.stringify(json));
  fs.writeFileSync(path.join(out, 'files.txt'), outcomes.sort().join('\n') + '\n');
  fs.writeFileSync(path.join(out, 'not-run.txt'), skipped.map(([f, e]) => `${path.relative(reactRoot, f)}\t${path.relative(reactRoot, e)}`).join('\n') + '\n');
  console.log(`done in ${Math.round((Date.now() - started) / 1000)} s: ${aggregated.numPassedTests} passed, ${aggregated.numFailedTests} failed, ${aggregated.numPendingTests} skipped, ${aggregated.numRuntimeErrorTestSuites} files did not run; ${skipped.length} files with another environment not run`);
  process.exit(0);
}

if (command === 'serve') {
  // Every file whose environment the page runs, so a probe browser can run any of them.
  for (const f of listTests()) {
    const env = environmentOf(f);
    if (jsdomEnvironments.has(env)) pageEnvironments.set(f, env);
  }
  await listen();
  console.log(`serving http://localhost/ (${pageEnvironments.size} files; open http://localhost/?file=<absolute path>)`);
} else {
  await run();
}
