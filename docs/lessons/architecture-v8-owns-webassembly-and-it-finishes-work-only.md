# Architecture: V8 owns WebAssembly, and it finishes work only when the embedder pumps

**Date**: 2026-09-24
**Lesson**: Two separate defects broke every WebAssembly API. Generated bindings shadowed V8's own `WebAssembly`, and nothing ran the tasks V8 posts to the platform.

**Why**: `wasm-js-api.idl` describes an API that the JavaScript engine implements, the way it implements ECMAScript. `registerNamespacesGeneric` registered the generated namespace over V8's, so `WebAssembly.compile(bytes)` reached a stub and threw "Not enough arguments". Blink binds none of this IDL. Behind that, V8 finishes an async compile, and runs FinalizationRegistry cleanup, through foreground tasks it posts to the platform. `v8::platform::PumpMessageLoop` runs them, and Crane never called it, so the compile promise never settled.

**Fix**: `interface_bindings.namespaceIsEngineProvided` is the list of namespaces the bindings leave alone, and it defaults to "ours". `pumpPlatformTasks` runs in each event loop turn and at the end of each worker turn: pump, then a microtask checkpoint after every task that ran, as d8's `ProcessMessages` does. Pinned by `tests/v8/engine_provided_namespace_test.zig` and `tests/v8/platform_task_pump_test.zig`.

**Takeaway**: **An IDL file for a JavaScript-engine API is documentation, not something to bind.** And an engine that posts tasks to its platform is waiting on its embedder: if a promise never settles and no Zig code is involved, check that someone pumps.
