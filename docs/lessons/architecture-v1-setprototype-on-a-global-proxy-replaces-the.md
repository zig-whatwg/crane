# Architecture: V1 SetPrototype on a global proxy replaces the global object

**Date**: 2026-09-25
**Lesson**: `wrapInstanceAsV8Object`'s cache-hit branch re-prototypes the cached wrapper with the V1 `v8_Object_SetPrototype`. For a realm's global scope that wrapper is the global PROXY, and the call succeeds: it replaces the proxy's hidden prototype, which is the global object itself.

**Why**: V1 SetPrototype is `from_javascript=false`, so V8 works on the proxy's own map, and that map is not immutable-proto (only templates that ask for it are, api-natives.cc `CreateApiFunction`). A Window never reached the branch only because the name-keyed `getBoundV8Global` returns early.

**Fix**: the cache hit returns a WorkerGlobalScope's wrapper untouched (7db027296, the workers lane), pinned by `crane/wk-global-scope.any.js`.

**Takeaway**: **Use only the V2 prototype calls on a global proxy. Any path that can hand back a global's wrapper must not touch its prototype.**
