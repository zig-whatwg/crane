# Architecture: A FunctionTemplate made per object keeps that object for its context's life

**Date**: 2026-10-11
**Lesson**: V8 caches every function it instantiates from a cacheable FunctionTemplate in the native context, for the context's life, so a template made per object - a method closure, a getter - pins its function, its data and whatever the function is stored on; make per-object functions with `Function::New` (`v8_Function_NewWithData`), which is not cached.

**Why**: `FunctionTemplate::New` makes a cacheable template (`FunctionTemplateNew(..., do_not_cache = false, ...)`, src/api/api.cc), and `ApiNatives::InstantiateFunction` (src/api/api-natives.cc) stores the instantiated JSFunction with `TemplateInfo::CacheTemplateInstantiation(..., CachingMode::kUnlimited, ...)` in the native context's instantiation cache. `Function::New` passes `do_not_cache = true`: the function is an ordinary heap object, collected with what references it. Disposing our Global of the template or the function changes nothing about the cache.

**What Happened**: Every Intl constructor in intl_binding.zig made two to twenty FunctionTemplates per object for its methods, and the DateTimeFormat's, NumberFormat's, Segmenter's and Locale's passed the object itself as the template's data. The cache held each function, each function's template held the object, so no Intl object was collectable while its realm lived - per construction, more cache entries, more objects, more native state (lane intlleak; `new Intl.Locale()` was +2,048 B of handles and ~94 KB of RSS per construction on base).

**Fix**: `defineMethod` in intl_binding.zig makes each method with `v8_Function_NewWithData(context, callback, null, 0)` and releases the Global. The methods find their object through `this`, so they need no data at all. Interface templates made once per isolate (template_registry, the Intl constructors in `registerGlobal`) stay templates: one cache entry per realm is the point of them.

**Takeaway**: **A FunctionTemplate is for a function made once per realm; anything made per object or per call is `Function::New`, or it lives as long as the realm.**
