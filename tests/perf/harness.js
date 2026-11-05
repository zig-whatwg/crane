// Crane's benchmark harness (docs/performance.md, "The harness"): the same file in Crane,
// Chrome, Firefox, Safari and Lightpanda. It uses only what every one of them has - fetch,
// performance.now(), promises, URLSearchParams - and reports to the benchmark server
// (tools/perf_bench/server.zig) with a POST to /__perf/mark for each mark. The server reads
// the engine's process set (CPU, instructions, memory) when each mark arrives and answers
// only after it has, so the page is idle while it is read.
//
// A page declares its workloads and the harness runs them on its load event:
//   perf.add(name, { ops, setup(), run(n), teardown() })   timed: `run(ops)` is one sample
//   perf.chain(name, ready)                                the page is one step of a chain;
//                                                          `ready()`, when given, returns a promise
//                                                          the page is ready at (an app's data
//                                                          rendered), else the load event is
//   perf.idle(name)                                        the page loads and is left alone
// `run` may return a promise; a sample then ends when it settles. `this` in setup, run and
// teardown is one object per workload, for its state. A setup that throws perf.Unsupported
// marks the workload unsupported in this engine (the message says what is missing).
//
// The URL's query: perf=<token> (from the runner), iterations, warmup, steps (a chain's
// length), step (this document's place in the chain).
(function () {
  'use strict';
  const params = new URLSearchParams(location.search);
  const token = params.get('perf') || '';
  const iterations = Math.max(1, +(params.get('iterations') || 10));
  const warmup = Math.max(0, +(params.get('warmup') || 3));
  const steps = Math.max(0, +(params.get('steps') || 0));
  const step = Math.max(0, +(params.get('step') || 0));
  const workloads = [];
  let chainName = null;
  let chainReady = null;
  let idleName = null;

  class Unsupported extends Error {}

  async function post(type, body) {
    const message = Object.assign({ token, type }, body || {});
    try {
      const r = await fetch('/__perf/mark', {
        method: 'POST',
        body: JSON.stringify(message),
        headers: { 'Content-Type': 'application/json' },
        cache: 'no-store',
      });
      await r.text();
    } catch (e) {
      // Nothing to report to: the runner times the page out.
    }
  }

  function describe(e) {
    if (e && e.stack) return String(e.stack).slice(0, 2000);
    return String(e).slice(0, 2000);
  }

  // A page's uncaught errors go to the run's log: the engines without a console in the
  // runner's view still say what went wrong.
  addEventListener('error', (e) => { post('log', { message: 'error: ' + (e.message || describe(e.error)) }); });
  addEventListener('unhandledrejection', (e) => { post('log', { message: 'unhandled rejection: ' + describe(e.reason) }); });

  async function runOne(w) {
    const ctx = {};
    try {
      if (w.setup) await w.setup.call(ctx);
    } catch (e) {
      await post('error', { workload: w.name, message: describe(e), unsupported: e instanceof Unsupported });
      return;
    }
    try {
      for (let i = 0; i < warmup; i++) {
        const r = w.run.call(ctx, w.ops);
        if (r && typeof r.then === 'function') await r;
      }
      await post('begin', { workload: w.name });
      const samples = [];
      for (let i = 0; i < iterations; i++) {
        const t0 = performance.now();
        const r = w.run.call(ctx, w.ops);
        if (r && typeof r.then === 'function') await r;
        samples.push(performance.now() - t0);
      }
      await post('end', { workload: w.name, ops: w.ops, wall_ms: samples });
    } catch (e) {
      await post('error', { workload: w.name, message: describe(e), unsupported: e instanceof Unsupported });
    }
    try {
      if (w.teardown) await w.teardown.call(ctx);
    } catch (e) {
      await post('log', { message: w.name + ' teardown: ' + describe(e) });
    }
  }

  async function runTimed() {
    for (const w of workloads) await runOne(w);
    await post('done', {});
  }

  async function runChain(loadMs) {
    await post('step', { workload: chainName, step, load_ms: loadMs });
    if (step + 1 < steps) {
      const next = new URL(location.href);
      next.searchParams.set('step', String(step + 1));
      location.assign(next.href);
    } else {
      await post('done', {});
    }
  }

  function start() {
    // Time from this document's time origin (its navigation's start) to its load event.
    const loadMs = performance.now();
    // After the load event's task, so that nothing the page does in `load` is timed as a workload.
    setTimeout(async () => {
      if (chainName) {
        // A page that says when it is ready (its data rendered) is timed to then, or to its
        // load event if that is later.
        // The promise resolves with performance.now() at the moment the page was ready.
        const ready = chainReady && chainReady();
        if (ready && typeof ready.then === 'function') {
          let readyMs = loadMs;
          try {
            const t = await ready;
            readyMs = typeof t === 'number' ? t : performance.now();
          } catch (e) {
            await post('log', { message: chainName + ' ready failed: ' + describe(e) });
          }
          return runChain(Math.max(loadMs, readyMs));
        }
        return runChain(loadMs);
      }
      await post('loaded', { load_ms: loadMs });
      if (idleName) return;
      runTimed();
    }, 0);
  }

  const perf = {
    Unsupported,
    add(name, spec) {
      workloads.push({ name, ops: spec.ops || 1, setup: spec.setup, run: spec.run, teardown: spec.teardown });
    },
    chain(name, ready) { chainName = name; chainReady = ready || null; },
    idle(name) { idleName = name; },
    // For a page's own scripts: a deterministic pseudo-random sequence, so every engine
    // gets the same data.
    random(seed) {
      let s = seed >>> 0 || 1;
      return () => {
        s ^= s << 13; s >>>= 0;
        s ^= s >>> 17;
        s ^= s << 5; s >>>= 0;
        return s / 4294967296;
      };
    },
  };
  globalThis.perf = perf;

  if (document.readyState === 'complete') start();
  else addEventListener('load', start, { once: true });
})();
