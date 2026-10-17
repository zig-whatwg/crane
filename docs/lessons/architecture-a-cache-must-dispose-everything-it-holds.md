# Architecture: A cache must dispose everything it holds

**Date**: 2026-10-16
**Lesson**: The isolate's template storage had two maps and disposed one; every template only in the other - each iterable interface's iterator prototype template - outlived the storage, one Global per worker realm that iterated.

**Why**: `IsolateTemplates.deinit` disposed the `registered` map's templates and assumed `templates` (the binding's cache) held nothing else, because the interface templates are in both. `iteratorPrototypeTemplate` (interface.zig) puts the "<Interface> Iterator" template in `templates` alone. A worker realm ends its storage with the realm (destroyWorkerRealmIn -> cleanupTemplateStorage), so each worker realm that iterated Headers, FormData or URLSearchParams left one Global<FunctionTemplate> per interface - a Window agent one per agent.

**What Happened**: lane sw1-b2's leaks --atExit over the cache-storage worker variants found 21 x 16 B `v8_FunctionTemplate_New` roots from `V8Interface(Headers).returnNewIterator` on worker threads, read at first as "one per call". tests/v8/worker_iterator_template_test.zig measured it with V8's own count: 3 handles per dedicated worker realm (96 -> 480 bytes over 4 realms), flat over 50 rounds of iteration inside one realm - per realm, not per call.

**Fix**: `deinit` disposes every distinct template either map holds, once each (a set of the two maps' values; one in both is one handle). The test runs dedicated, shared and service worker realms.

**Takeaway**: **When a cache ends, dispose what IT holds, not what another map is assumed to cover - and measure a "per call" leak per call and per realm before believing either.**
