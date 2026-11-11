# Workflow: An adapter for an engine step runs it twice once the engine does the step itself

**Date**: 2026-11-11
**Lesson**: Where Crane's V8 adapter performed a spec step the old engine skipped, an engine upgrade that implements the step leaves the adapter still doing it: the step runs twice, and nothing fails to compile.

**Why**: An adaptation sits in front of the engine's own entry point (a Proxy around a constructor or a callable, a descriptor rewritten before the call). It cannot tell whether the engine behind it now does the same work. Each extra run of a step is observable whenever the step reads script-visible state: a getter, a `then`, a property read in an "order of evaluation" test.

**What Happened**: Lane v8up, V8 13.1 to 15.7, twice in two batches:
- b3c: the memory64 `address` adaptation read a Memory/Table descriptor's `address` and handed V8 a Proxy that answered the old `index` spelling. V8 15.7 reads `address` itself, so every descriptor read `address` twice (wpt wasm/jsapi memory/table "Order of evaluation"). The adaptation's own comment said to remove it at V8 >= 13.3; nobody re-read it at the upgrade.
- b3d: the JSPI Suspending adaptation (a Proxy apply trap) ran "create a suspending function" step 3.15, PromiseResolve, with the import realm's intrinsics. V8 15.7 runs step 3.15 itself (turboshaft wasm-wrappers.h BuildSuspend, the importing instance's native context). A promise of the page's realm returned by another realm's function was assimilated by the other realm first, which read its `then`: Chrome 157, Firefox 159 and Safari 27 all resolve it without reading `then` (probe tmp/probes/v8up-jspi-realm). The RED was that case; removing the adaptation fixed it.

**Fix**: At an engine upgrade, list every adaptation in the adapter (search for the old version number in comments: "V8 13.1", "13.1.203") and, for each, find the new engine's own code for the same step. If the engine now does it, remove the adaptation, and write a test of the case where the step's double run is observable, not just the case it was written for. Keep each adaptation's comment naming the engine version and the engine function it stands in for, so the next upgrade can check it.

**Takeaway**: **An adaptation outlives the engine gap it filled without any error: at every engine upgrade, check each one against the new engine's own step, and test the case where running the step twice shows.**
