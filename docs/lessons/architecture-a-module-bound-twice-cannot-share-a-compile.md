# Architecture: A module bound twice cannot share a compile

**Date**: 2026-09-26
**Lesson**: Zig rejects one source file in two modules anywhere in a compilation's import graph - even where the second path is never analysed - so a test target cannot bind `engine_impl` to a test adapter while anything it imports reaches the V8 binding.

**Why**: The error is structural, not semantic: `file exists in modules 'engine' and 'engine0'`. `runtime` imports `v8`, `v8` imports `impls`, and `impls` imports `engine`, so every target that imports `runtime` already contains the V8-bound `engine`; binding it again to a test adapter puts `engine_protocol.zig` in two modules.

**What Happened**: The protocol spike (lane/protocol, e44c58a91) wanted runtime tests to run against a tiny NotSupported adapter with no V8. The first wiring failed with the error above; the spike worked around it with a copy of the runtime module minus its `v8` import.

**Fix**: Drop `runtime`'s `v8` import - its only use is realm.zig's `populateIntrinsics`, called from Context.zig, which moves into the adapter's `createWindowRealm`. Until then, a V8-free test target uses a runtime module instance without that import.

**Takeaway**: **Before giving a module a second binding, check that nothing in the target's import graph reaches the first - Zig rejects the pair even in code it never analyses.**
