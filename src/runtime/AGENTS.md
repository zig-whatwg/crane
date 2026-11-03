# The JavaScript engine

Moved verbatim from AGENTS.md (2026-11-03). The core keeps the rule as one line and points here. The check that holds it, `zig build lint-engine`, and its baseline are in [tools/AGENTS.md](../../tools/AGENTS.md).

## The engine boundary

**Crane's JavaScript engine is an adapter, and the protocol is the only way to
reach it.** V8 is one implementation, statically linked on desktop and server;
on iOS Crane links the system JavaScriptCore dynamically instead. Behaviour may
differ between targets only where the difference is declared - never by
accident.

The protocol is the `engine` module, `src/runtime/engine_protocol.zig`. Its
signatures and doc comments are the contract; build.zig binds it, as
`engine_impl`, to the adapter `-Dengine=v8|jsc|quickjs` selects, so dispatch is
static. Whether an adapter links its engine statically (V8) or dynamically
(JavaScriptCore on iOS) is the adapter's business; the protocol does not change.
What it is: [docs/engine-protocol.md](docs/engine-protocol.md). How to move code
onto it: [docs/engine-protocol-recipes.md](docs/engine-protocol-recipes.md), a
recipe per intent.

```
src/runtime/engine_protocol.zig      THE PROTOCOL: module "engine", one pub inline fn per operation
src/runtime/engines/v8/              the V8 adapter: protocol.zig and protocol_*.zig (the operations),
                                     v8_wrapper.cpp, ffi.zig, conversions, the wrapper cache, context_manager
src/runtime/engines/{jsc,quickjs}/   the other adapters' protocol.zig
tests/runtime/protocol_test_adapter.zig   the engine-less adapter the runtime-tier tests bind
tests/v8/                            the V8 adapter's tests
everything else                      `const engine = @import("engine");`, runtime.Instance,
                                     runtime.JSValue, runtime.Context
```

1. **V8 types and calls live only in the adapter.** Outside
   `src/runtime/engines/v8/` and `tests/v8/` - impls, src/html, src/dom,
   src/fetch, src/browser, src/websocket, streams, the parsers, tools - there
   is no `@import("v8")`, no `v8_*`, and no Isolate, Global, Local or
   HandleScope. The generated WebIDL interfaces are engine-neutral comptime
   tables the adapter consumes; codegen never emits an engine call.
2. **Everything else reaches the engine through the protocol:** `engine.op(...)`,
   no function pointers, no optional unwrapping. **Every `pub inline fn` in
   engine_protocol.zig is an operation**, and a comptime check makes each
   adapter declare each one with exactly its types - a missing or mis-typed
   operation is a compile error. Helpers built over operations are plain
   `pub fn`s.
3. **Ownership is in the types.** A `JSValue` parameter is borrowed for the
   call. What the caller must release has an owning type - `engine.Owned`
   (`release()` or `take()`, exactly once), `Completion`, `CallbackFunction`,
   `CallbackInterface`, `PromiseCapability` - and its declaration says so.
   Nothing crosses the seam as an untyped engine pointer or with a flag saying
   who frees it. "Every `v8_*` return is owned" is an adapter-internal rule.
4. **A platform object converts in its relevant realm.** Every operation turns
   an `.instance` into its wrapper in `instance.ctx`, whichever realm it
   entered. Results are made in the current realm, `engine.currentRealm()` -
   null outside script, never "whatever context is entered".
5. **Capabilities are tri-state comptime constants.** `engine.capabilities.X`
   is `.native`, `.emulated` or `.unsupported`. A gated operation compiles only
   inside `if (engine.capabilities.X != .unsupported)`, and the host implements
   the declared fallback for the rest; nothing assumes V8. The no-snapshot
   startup path keeps working, because JavaScriptCore runs on it.
6. **A new engine need is a new protocol operation, named after the spec
   concept** - an ECMAScript abstract operation, a WebIDL or HTML algorithm -
   or, where there is no spec, after the engine concern. Never a pass-through
   with a V8-shaped signature: if the JavaScriptCore C API could not implement
   it, it is shaped like V8. The integrator owns engine_protocol.zig; request
   the operation the way you request a grant. It lands with its V8
   implementation, entries in the JavaScriptCore, QuickJS and test adapters
   (`error.NotSupported` where they cannot answer), a tests/v8 test with values
   made the way the binding makes them, and its line in docs/engine-protocol.md.
7. **The runtime Engine table is gone** (deleted with the final cleanup, f84096c88).
   Nothing reaches the engine through a function-pointer table: the runtime
   tier itself imports `engine` and calls the protocol (releasing an unwrapped
   instance is `engine.hasWrapper`, [PutForwards] is the protocol's Set). Do
   not bring a table back to break an import cycle - the runtime <-> engine
   cycle is the same shape as the facade <-> adapter one and builds.
8. **Existing debt is paid file by file.** Editing a file that makes direct V8
   calls or table calls means moving that file onto the protocol in the same
   change, by its recipes.
