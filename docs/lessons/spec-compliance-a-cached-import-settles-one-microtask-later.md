# Spec Compliance: A cached import() settles one microtask later, not after a task

**Date**: 2026-10-18
**Lesson**: When every module of an import()'s graph is already in the module map, HTML's "fetch a single module script" step 5 runs onComplete at once, and ECMA-262 ContinueDynamicImport links and evaluates in a reaction to the settled loadPromise. That ordering is one realm microtask (`engine.queueRealmMicrotask` -> `finishDynamicImport`), and it needs no new protocol operation.

**Why**: Crane's asynchronous module loader (`module_script.AsyncModuleLoader`) completed every graph from a queued task. That is right for a script element, whose result the spec hands over from onComplete in a task (lesson: a result handed over from onComplete arrives in a task). It is wrong for import(): a task lets the whole microtask queue drain first, so `microtasks/basic.any.js` counted 1000 ticks where it expects fewer.

**What Happened**: The browsers split on it. At wpt.fyi stable df642c4142, "import() should not drain the microtask queue when loading an already loaded module" was a PASS in Safari in the Window and in workers, a PASS in Firefox in workers but a FAIL in its Window, and a FAIL in Chrome. Blink's ModuleMap posts a task even for a finished entry (`DispatchFinishedNotificationAsync`); Gecko resumes the waiting request synchronously (`ModuleLoaderBase::WaitForModuleFetch` -> `ResumeWaitingRequest`). A per-global browser majority would have kept the task in the Window. The integrator ruled that golden rule 2's first case applies: wpt PR #35949 added the test together with whatwg/html#8264 (HostLoadImportedModule, tc39/ecma262#2905), and Safari ships that change.

**Fix**: A loader Client flag, `settle_cached_in_microtask`, which the Window's and the workers' import() set. When `startGraph` finds the graph settled with no fetch pending, it queues the completion as a realm microtask instead of a task. The microtask owns the graph exactly as a queued task does (`task_queued`), and its dropped end is the task's `dropTask`. Script element graphs keep their task.

**Takeaway**: **Before a host makes a step synchronous to match the spec, trace what the engine half does next: ContinueDynamicImport already defers link and evaluate by one reaction, so "one microtask later" is the spec's ordering, not an approximation of it.**
