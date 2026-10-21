# Architecture: Promise lifecycle hooks do not observe every reaction registration

**Date**: 2026-10-21
**Lesson**: V8 promise lifecycle hooks cannot recover the incumbent settings object at every Promise reaction registration.

**Why**: ECMAScript permits a Promise species constructor to return an existing promise or a plain capability object. Registration can create no Promise at all. An initialization hook observes allocation, not PerformPromiseThen. A job's execution-time realm cannot reconstruct its registration-time incumbent.

**What Happened**: A native Isolate::SetPromiseHook probe in linked V8 13.1.99 observed init/before/after counts of 1/1/1 for plain then, 0/1/1 for a species returning an existing promise, 0/0/0 for a species returning a plain object, and 0/1/1 for thenable assimilation. Every callback executed. Context::SetPromiseHook also aborted because this V8 prebuilt disables JavaScript Promise hooks.

**Fix**: Stop the proposed public-API incumbency emulation rather than install a partial hook. Keep the coverage test and report the engine contract that is missing. Relevant linked sources are `src/builtins/promise-then.tq`, `promise-abstract-operations.tq`'s InnerNewPromiseCapability/PerformPromiseThen, and `builtins-microtask-queue-gen.cc`'s promise-hook dispatch. BackupIncumbentScope provides dynamic stack scope only.

**Takeaway**: **Before using allocation or lifecycle hooks as registration hooks, test legal paths that allocate nothing and return unusual capabilities.**
