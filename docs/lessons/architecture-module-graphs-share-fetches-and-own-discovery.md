# Architecture: Module graphs share fetches and own discovery

**Date**: 2026-10-07
**Lesson**: Coalesce module resource fetches per document while keeping each graph root's discovery and completion state independent.

**Why**: Static imports resolve synchronously when V8 links a record, but their resource fetches must leave the event loop free. A module record shared by two roots cannot also hold both roots' pending counts or cycle detection state.

**What Happened**: A slow imported resource blocked script-element preparation for about one second, preventing the parser and a fast deferred script from proceeding. The existing synchronous module loader had completed-cache entries and record-level depth-first flags, but no in-flight callback list. Native tests and Crane probes established the blocking behavior before implementation.

**Fix**: Give Document an asynchronous loader that owns in-flight resource requests and their waiters. Give each graph its own visited URLs, pending count, and source-order error walk. Parse resources in a queued realm task, retain completed records in the document's module map, and link only after the graph's resources are ready. Detach graph waiters before canceling their owners; cancel shared transport when its last waiter ends. A queued payload uses an allocator that survives document destruction and remains task-owned until callback or drop. Document disposes its loader before its module records. Independent engine-owned roots hold the element, document, and execution queue separately.

The cached HTML revision dated 2026-10-02 removes a failed fetch's module-map entry before notifying its callback list, permitting a later retry. It does not cache a permanent null result. Read the complete current fetch-single algorithm; the older synchronous sentinel behavior is not a template for the asynchronous path.

Engine design reference: [Blink ModuleTreeLinker](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/modulescript/module_tree_linker.cc), particularly `FetchDescendants`, `NotifyModuleLoadFinished`, and `FindFirstParseError`. [WebKit ScriptModuleLoader](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/bindings/js/ScriptModuleLoader.cpp) and [CachedModuleScriptLoader](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/bindings/js/CachedModuleScriptLoader.cpp) detach loader clients during destruction and release promise owners without running completion. Crane's dynamic import protocol currently exposes completion but no release-only cancellation; silently canceling that owning request requires a protocol operation, not an abandoned handle.

**Takeaway**: **Share the resource fetch, keep graph traversal local to each root, and make cancellation detach every pending callback before releasing its owner.**
