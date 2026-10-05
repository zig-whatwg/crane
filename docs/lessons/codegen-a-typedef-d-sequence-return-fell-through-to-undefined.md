# Codegen: A typedef'd sequence return fell through to undefined

**Date**: 2026-10-04
**Lesson**: Every operation returning `PerformanceEntryList` (`typedef sequence<PerformanceEntry>`) - getEntries, getEntriesByType, getEntriesByName, takeRecords - was generated as returning a Zig slice, and the binding's `convertReturnValue` has no slice case: it falls through to `return undefined`. A direct `sequence<Interface>` return is generated as `runtime.JSValue` (the impl builds the Array with `engine.createSequenceOfPlatformObjects`), so only a typedef'd one escaped.

**Why**: The operation return mapper kept a registered typedef's NAME (`PerformanceEntryList`), whose generated typedef file resolves to `[]const *runtime.Instance`, instead of mapping the typedef's target the way it maps the same type written out. Nothing failed to compile: the binding's fallback for an unknown return type is undefined.

**What Happened**: Found while implementing the Performance Timeline: the impls would have returned correct slices and script would have read `undefined` - the navigation-timing cluster "Cannot read properties of undefined (reading 'getEntriesByType')" would only have moved one step. The integrator fixed the mapping on main (a typedef'd sequence return maps to `runtime.JSValue`, as every direct sequence return does); the lane built against hand-retyped generated returns, uncommitted, until that landed.

**Fix**: Codegen maps a typedef whose target is a sequence (anything the written-out type maps to `anyopaque`/JSValue) like the written-out type; the impls build the Array in the current realm.

**Takeaway**: **A typedef must map exactly as its target would; when a binding's fallback for an unknown return type is `undefined`, a type the mapper mis-resolves compiles and silently returns nothing - check the generated signature of every operation you implement against how the binding converts it.**
