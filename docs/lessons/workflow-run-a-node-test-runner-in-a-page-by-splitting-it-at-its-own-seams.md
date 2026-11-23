# Workflow: Run a Node test runner in a page by splitting it at its own seams

**Date**: 2026-11-23
**Lesson**: To run a jsdom-based Jest suite with a browser engine as the DOM, keep the runner's own runtime, test framework and matchers unmodified in the page and leave in Node only what has no DOM in it - config, module resolution, the code transform and file reads - reached by synchronous XHR whose answers are memoized and prefetched.

**Why**: The suite is the measurement, so none of Jest's code that a test observes may be replaced: `jest-runtime`'s module registry, `jest-circus`, `expect`, and the project's own environment class (React's ReactJSDOMEnvironment over jest-environment-jsdom). Those are synchronous CommonJS code that calls `resolve` and `transform` synchronously, so the page needs answers synchronously. A naive proxy makes thousands of synchronous round trips per file and eats the first test's timeout.

**What Happened**: Lane react1 (tests/frameworks/react-jest) ran React 19.3.1's jsdom projects - 3,500+ tests - in Crane, Chrome, Firefox and Safari. The split:
- **Node (server.mjs):** jest-config's `readConfigs`, `jest --listTests`, the runtime's Resolver and `createScriptTransformer` with React's preprocessor, a read-only `fs`.
- **The page (boot.js, run-test.js):** a CommonJS loader running jest-runtime, jest-circus, the environment class and the tests; `require('jsdom')` answers the page's own window (outer realm) or an iframe's (the test realm).
- Node's core modules: published browser stand-ins (path-browserify, buffer, events, util plus node-inspect-extracted for Node's exact `util.inspect`/`format`), and own stand-ins where none fits (`vm.compileFunction` compiles a classic script, `async_hooks` a synchronous AsyncLocalStorage).

Speed came from three things. Node memoizes each answer keyed by the raw request text; re-encoding the parsed body dropped `undefined` properties and missed the key. Node learns, per first request, the sequence that follows, and returns it as a prefetch. A warm-up file is run and discarded. Before the prefetch the first test of large files timed out on synchronous XHR alone.

Frame names also matter. React's tests read `error.stack`, and Node names a module's frames `Object.<anonymous>`. `eval` or `new Function` adds `eval` frames ("Object.eval"). The page compiles each module as a classic `<script>` inside a closed shadow root, wrapped in `({"Object.<anonymous>": function (...) {...}})["Object.<anonymous>"]`, so frames read as Node's.

**Fix**: Draw the split before writing glue:
1. List what the runner does that needs Node: files, the transform, the resolver's file-system walk.
2. Move only that to the server, answering synchronously.
3. Run everything a test can observe in the page unmodified, with Node's globals from published browser ports or minimal stand-ins.
4. Memoize answers by raw request text and prefetch learned sequences.
5. Compile module code the way Node does as far as stacks show it.

**Takeaway**: **Split a Node test runner where its code stops touching the test: the page runs the runner's own runtime and matchers unmodified, Node only resolves, transforms and reads, and every synchronous answer is memoized and prefetched.**
