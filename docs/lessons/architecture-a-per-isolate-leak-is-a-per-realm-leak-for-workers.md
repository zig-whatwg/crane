# Architecture: A per-isolate leak is a per-realm leak for workers

**Date**: 2026-09-27
**Lesson**: Every handle leaked while building interface templates leaked once per agent for a Window and once per realm for a worker. A worker realm rebuilds every template, because its end clears the isolate's templates. A test that runs Window realms could not see it.

**Why**: Templates are cached per isolate (template_registry, isolate_templates). A Window agent builds them once and reuses them for every realm it makes, so a Window realm round is flat even when template building leaks. A worker realm owns its isolate: destroyWorkerRealmIn calls `template_registry.clearForIsolate`, and the next worker realm builds them all again. The adapter's live counters did not show the whole cost either. They count String, Object and Context Globals made through a few FFIs, not the Globals of templates or Values, and some disposals never decrement them. V8's own `v8_Isolate_GetGlobalHandleBytes` counts every live Global.

**What Happened**: While adding the worker realm record (a91d34ca4), a handle-flatness test showed a whole worker realm round was not flat, with or without the record. Phase-by-phase measurement inside createWorkerRealm (global handle bytes and counters after each step) placed about 207 KB in installForScope and 7 KB in registerWorkerInterfaces:
- createTemplateCore never released the class-name string, each eager property's name, each constant's name and Number, or its PrototypeTemplate handle.
- registerMethod never released each method's name or FunctionTemplate.
- `registerGlobal` took the context's global for every call and never released it. Twelve Globals of the global proxy kept every worker context alive after destroyWorkerRealm.

Per worker realm this came to 205,120 bytes of global handles (6,410 handles) and one native context. A Window agent kept 509,472 bytes after its first realm where 36,224 (its templates) are needed. The Window per-realm test (page_realm_operations_test.zig) was flat the whole time.

**Fix**: Release each handle once the template call that reads it has returned. Every one of these FFIs takes a Local from the Global and V8 keeps its own reference, which the C++ bodies show. registerWorkerInterfaces takes the global once and uses registerGlobalFast. The test is in tests/v8/engine_worker_realm_test.zig: three worker realm rounds in one agent, global handle bytes within one handle and native contexts equal. It was red at 205,120 -> 820,480 bytes and 1 -> 4 contexts.

**Takeaway**: **Test handle flatness per realm kind. A worker realm pays every per-isolate cost a Window agent pays once, so measure with global handle bytes and native contexts, not the live counters.**
