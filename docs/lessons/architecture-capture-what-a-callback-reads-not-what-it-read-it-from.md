# Architecture: Capture what a late callback reads, not the object it came from

**Date**: 2026-09-30
**Lesson**: import.meta.resolve can be called long after its module record is gone, so the builtin captures what "resolve a module specifier" reads - the module script's settings object (its realm) and base URL (the string import.meta.url is) - not a handle to the module.

**Why**: HostGetImportMetaProperties makes `resolve` a closure over moduleScript. A V8 FunctionCallback's data must be a Value, a Module is not one, and a Global<Module> captured for it would need a weak callback to free, or would keep every module alive. The algorithm reads only the base URL and the settings object: `import.meta.url` is exactly "moduleScript's base URL, serialized", and the function's own realm is the module's.

**What Happened**: The first design looked for a way to hand the module to the callback; the fences on v8_wrapper.cpp made that expensive, which forced the question of what the steps actually read.

**Fix**: `HostHooks.importMetaResolve(host, realm, base_url, specifier, allocator)`; ProtocolInitializeImportMeta makes the function with import.meta.url as its data, and the callback passes the current realm (lane/scripts 922d1559c).

**Takeaway**: **Before capturing an object for a callback that may run after it, list what the callback's steps read; capture those values, and there is nothing left to keep alive or to find dangling.**
