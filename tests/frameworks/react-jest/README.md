# React's own Jest suite, in a browser in jsdom's place

React's main test suite - the Jest tests across `packages/` - runs on jsdom, a stand-in browser in Node.
This harness runs the same files, with the same Jest, in a real browser page instead: Crane (its release
console) or Chrome for Testing (through Playwright). The user's ruling, 2026-11-22: "Crane replaces jsdom".
The third column is React's own `yarn test` under jsdom, same commit, same Node.

The harness is test glue, like `../todomvc/`; `build.zig` never runs it.

## The shape: Jest split at its own seams

Jest's runner already splits a run in two: the parent process (configuration, the file list, the haste map
and resolver, the transform cache) and a worker per file (an environment, `jest-runtime`, the test framework).
The harness keeps that split and moves the worker into the page.

- **Node, `server.mjs`**: React's own Jest packages (from React's `node_modules`, at React's lockfile
  versions) do what Jest does outside the test. `jest-config` reads `scripts/jest/config.source.js` (CI's
  `-r=experimental --env=development`, also `yarn test`'s default), `jest --listTests` picks the files,
  `jest-runtime`'s `createContext` builds the haste map and `jest-resolve`'s Resolver, and `@jest/transform`'s
  ScriptTransformer runs React's `scripts/jest/preprocessor.js`. It serves the page at `http://localhost/`,
  which is jsdom's URL in Jest's environment (port 80; macOS lets an unprivileged process bind it on the
  wildcard address only, so the server answers loopback connections only).
- **The page, `page/boot.js`**: the document is `<!DOCTYPE html>` with an empty head and body, as jsdom's is
  (the boot script removes itself). `__reactJest.run(file)` does what a Jest worker does for one file
  (`page/run-test.js`, a step-for-step port of jest-runner's `runTestInternal`). Jest's own code -
  `jest-runtime`, jest-circus's runner and `jestAdapterInit`, `expect`, `jest-snapshot`, `jest-mock`,
  `@jest/fake-timers` - and React's environment class run unmodified, loaded the way Node loads CommonJS by
  the page's own loader. What only Node can answer (resolution, the transform, the checkout's files) is
  asked over synchronous `XMLHttpRequest`, so `require()` stays synchronous as in Jest; `jest-runtime` takes
  the resolver and the transformer as constructor arguments, so it needs no change for that.

## What stands in for what

- **jsdom.** Outside the test, `jest-environment-jsdom` asks the `jsdom` package for a window
  (`new JSDOM('<!DOCTYPE html>', {url: 'http://localhost/', runScripts: 'dangerously', pretendToBeVisual:
  true})`); `page/jsdom-environment.js` answers with the page's own window, and everything else the
  environment does runs as Jest wrote it. Inside a test, `require('jsdom')` (by Jest's `moduleNameMapper`)
  is `page/jsdom.js`: a test's `new JSDOM(html)` is a same-origin `<iframe>`, the browser's second document.
  jsdom's internal modules (`jsdom/lib/...`) stay jsdom's.
- **Node's core modules**, which Jest's environment lends a test even under jsdom: pinned browser packages
  (`package.json`: `path-browserify`, `buffer`, `events`, `assert`, `readable-stream`, `util`) or the
  harness's own (`page/core/`): `fs` is a read-only view of the checkout through the server, `vm` compiles
  in the page, `timers` and `worker_threads` are the browser's own timers and `MessageChannel` captured at
  page start (never a test's fakes), `async_hooks`' `AsyncLocalStorage` holds its store for the synchronous
  extent of `run()` only (no browser propagates async context). A module with no stand-in fails and says so.
- **Node's process.** Jest's code outside the test sees `process`, `Buffer`, `global` and `setImmediate` as
  Node gives them to a module, never as page globals. The test sees what jest-environment-jsdom puts on the
  window (its `process` copy, `Buffer`), as under jsdom. `process.env` is what React's `jest-cli.js` gives
  Jest's workers (`NODE_ENV`, `RELEASE_CHANNEL`), `CI` as GitHub Actions sets it, and `TZ=UTC` from React's
  `globalSetup`; the browsers get `TZ=UTC` in their process environment.
- **Uncaught errors**: the window's `error` event (jest-environment-jsdom forwards it, as under jsdom),
  `unhandledrejection` and `rejectionhandled` are Jest's parent-process events.
- **The console** stays the browser's (Jest's BufferedConsole only buffers output for its reporter).

## Running it

On a host with React 19.3.1 checked out and installed (`yarn install --frozen-lockfile`), its Node
(`.nvmrc`), this directory's packages (`npm ci`), and React's environment:

    NODE_ENV=development RELEASE_CHANNEL=experimental CI=true \
      node server.mjs run --react=<react> --browser=crane --console=<repl> --out=<dir> [--files=<regexp>]
    ... --browser=chrome --chrome=<Chrome for Testing> ...

Crane gets a fresh release console per file (`repl http://localhost/`, then
`await __reactJest.run(<file>)` typed into its console), as Jest gives each file a fresh environment;
Chrome gets a fresh browser context per file. Files whose `@jest-environment` is not React's jsdom
environment are not run; `<dir>/not-run.txt` names them with theirs. `<dir>/jest.json` is Jest's own
`--json` shape, which `fw_matrix import --reader=jest-json` reads.
