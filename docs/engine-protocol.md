# The engine protocol

Crane's JavaScript engine is an adapter, and the protocol is the only way to
reach it. This is the reference for what the protocol is and how it is
extended. The rules that bind every change are in AGENTS.md ("The engine
boundary"); how to move existing code onto the protocol is in
[engine-protocol-recipes.md](engine-protocol-recipes.md); why it was designed
whole before anything migrated is in
[the lesson](lessons/architecture-design-the-protocol-before-migrating.md).

The contract itself is `src/runtime/engine_protocol.zig`: every signature
there, and the doc comment on it, is authoritative. This file summarises; it
never overrides the code.

## 1. Shape

```
src/runtime/engine_protocol.zig          module "engine" - THE PROTOCOL
    const impl = @import("engine_impl");  bound by build.zig from -Dengine=
    pub inline fn createResolvedPromise(realm: Context, value: JSValue) Error!Owned {
        return impl.createResolvedPromise(realm, value);
    }
    ... one forwarding function per operation; its signature is the contract

src/runtime/engines/v8/protocol.zig      the V8 adapter's root (re-exported by the
                                          v8 module as `protocol`); protocol_*.zig
                                          beside it implement the areas
src/runtime/engines/jsc/protocol.zig     JavaScriptCore - NotSupported until it
src/runtime/engines/quickjs/protocol.zig   has an engine; QuickJS the same
tests/runtime/protocol_test_adapter.zig  no engine at all: what the runtime-tier
                                          tests bind
```

- Consumers write `const engine = @import("engine");` and call
  `engine.op(...)`. Dispatch is static: no function pointers, no optional
  unwraps, no `ctx.getEngine()`.
- In a V8 build `engine_impl` is the v8 module itself, whose root re-exports
  the adapter's protocol root: the protocol functions live beside the adapter
  files they call. Other engines bind `src/runtime/engines/<engine>/protocol.zig`.
- **Every `pub inline fn` in engine_protocol.zig is an operation.** A comptime
  block checks that the bound adapter declares each one with exactly the
  protocol's parameter and return types - a missing or mis-typed operation is
  a compile error naming it. Helpers built over operations
  (`getPropertyBoolean`, `getPropertyPlatformObject`) are plain `pub fn`s.
- In a test build the facade compiles an engine-less adapter's functions
  whole, so a stub nothing calls still type-checks. An adapter with an engine
  behind it (`links_engine = true`: V8) is compiled whole by its own tests
  instead (tests/v8), so that engine-neutral code reaching the facade does not
  have to link the engine.
- runtime does not import the V8 module, and must not: Zig rejects one file in
  two modules anywhere in a compile's import graph, so the runtime-tier tests
  (which bind the test adapter) need a runtime without it.

## 2. Types and ownership

The types are the ownership rule. Nothing crosses the seam as an untyped
engine pointer or a flag saying who frees it.

| Type | Meaning |
|---|---|
| `Context` | A realm's identity (`runtime.Context`). BORROWED wherever it is a parameter; stable until the realm is torn down. A retired realm has no engine realm behind it. |
| `Agent` | An ECMAScript agent: a V8 isolate, a JSC context group. Opaque. |
| `JSValue` | The IDL-level value (`runtime.JSValue`). As a parameter, always BORROWED for the call. As an impl's RESULT, the binding's: it releases it once set. Its handle carries no ownership flag - the holder's type says who releases it. |
| `Instance` | A platform object: the host's side of a wrapper. |
| `Owned` | A value the caller owns. Exactly one of `release()` (give it back) or `take()` (hand it, and the duty to release it, to something documented to take ownership - the binding, for an impl's result). `borrow()` lends it, BORROWED, while it is held - to an operation, never as an impl's result: a kept value is returned as `(try retainValue(realm, kept.value)).take()`. |
| `Completion` | ECMAScript's Completion Record from an operation that runs script: `normal` or `throw`, OWNED either way. |
| `CallbackFunction`, `CallbackInterface` | WebIDL's callback values: the function or object (OWNED) and the callback context (the incumbent realm when the value was converted). The invoke operations take them BORROWED. |
| `PromiseCapability` | WebIDL "a new promise": OWNED until `releasePromiseCapability`; its `promise` is a BORROWED view. |
| `ErrorInfo` | HTML "extract error information": BORROWED for the call it is handed to. |
| `Reporter` | HTML "report an exception", as the host supplies it to an operation that runs script. |
| `ModuleRecord`, `IteratorRecord`, `ImportRequest` | Opaque, OWNED until their release or finish operation. |

Slices an operation returns are allocated with the allocator the caller
passed, and are the caller's. Every operation that reads a value takes the
realm first.

### Errors

`Error = { OperationFailed, ExceptionReported, OutOfMemory, TypeError, ExceptionPending, DataCloneError, NotSupported }`

- `TypeError` - the spec throws a TypeError and nothing is thrown yet: the
  caller (a binding, from its error) throws it.
- `ExceptionPending` - script threw, or the engine threw on the spec's behalf;
  it is pending in the engine. Return without throwing another.
- `ExceptionReported` - script threw, the exception was reported through the
  operation's Reporter, and nothing is pending.
- `DataCloneError` - HTML serialization's DataCloneError, not yet thrown.
- `NotSupported` - this engine does not provide the operation.
- `OperationFailed` - the engine failed (no context, out of handles).

## 3. Realms

- `currentRealm()` - ECMAScript's current realm: while a binding runs, the
  realm of the function called. Null when no script runs; never "whatever
  context happens to be entered". An operation's results are made there.
- `entryRealm()` / `incumbentRealm()` - HTML's entry and incumbent settings
  objects' realms; the adapter keeps them as "prepare to run script" and
  "prepare to run a callback" push them.
- `functionRealm(value)` - GetFunctionRealm [exact_function_realm].
- **Relevant realm:** a platform object (`.instance`) converts to its wrapper
  in its relevant realm, `instance.ctx`, whichever realm the operation
  entered. A platform object has one wrapper, made in the realm it was
  created in.
- **Frames:** `createWindowRealm` with `parent` set makes a navigable's realm
  under its parent's - an iframe's, or a popup's under its opener's. It
  shares the parent's engine-level access (V8's security token; the
  WindowProxy's cross-origin checks stay the host's), is entered only for
  the calls that run in it (it is made while the parent's script runs), and
  ends before its parent does if it has not already. A parentless realm is
  the agent's entered realm for its life. A realm whose WindowProxy went on
  to a later one (`window_proxy_of`) is severed from its Window at its end:
  a function of it that script still holds finds no Window, not a freed one.

## 4. Capabilities

`engine.capabilities` is a comptime-known struct of tri-state `Support`
values: `.native` (the engine does it), `.emulated` (the adapter builds it on
the engine's public API; its deviations are listed at the adapter's
constant), or `.unsupported` (the host takes the declared fallback). The
operation is the same in all three, so hosts branch only on `.unsupported`:

```zig
if (engine.capabilities.promise_rejection_tracking != .unsupported) {
    handled = engine.promiseIsHandled(realm, promise);
}
```

A gated operation names its capability once, in its body; calling it outside
such a branch is a compile error that says so. On an engine without the
capability the branch compiles out.

| Capability | V8 | JavaScriptCore (public C API) | The host's fallback |
|---|---|---|---|
| `module_scripts` | native | unsupported - no module loader (FB24953657) | `<script type=module>` fires `error`; `import()` rejects with a TypeError |
| `promise_rejection_tracking` | native | unsupported - no tracker hook (FB24953666) | no `unhandledrejection` / `rejectionhandled` events |
| `reuse_window_proxy` | native | unsupported - no WindowProxy distinct from the global (FB24953676) | a navigation that makes a new Window gives `contentWindow` a new identity |
| `microtask_checkpoint_control` | native | unsupported - drains when its outermost call returns | checkpoints happen at API-call exit; report-before-checkpoint ordering is not guaranteed |
| `exact_function_realm` | native | unsupported - GetFunctionRealm is SPI | a callback's realm is the one recorded when it was converted |
| `restores_snapshots` | native | unsupported | every realm is created afresh (the no-snapshot startup path, which must keep working) |
| `can_block_control` | native | unsupported | [[CanBlock]] is the engine's default |
| `heap_statistics`, `heap_snapshots`, `diagnostic_counters` | native | unsupported | the diagnostics tier reports nothing |

Flip a JavaScriptCore capability when an iOS release makes the API public.
Structured serialization has no JSC API and is not a capability: the JSC
adapter will use Crane's own walker (src/html/structured_clone).

## 5. Operations

`engine_protocol.zig` groups them; each group names the spec it follows.

| Area | Operations |
|---|---|
| Engine and agents | `initializeEngine`, `deinitializeEngine`, `createAgent` (with the host's `HostHooks`), `destroyAgent`, `hasRunningScript`, `hasPendingEngineWork`, `runEngineTasks`, `notifyMemoryPressure` (a page let go: `.critical`; a hint: `.moderate`), `requestGarbageCollection` (testing only) |
| Realms | `createWindowRealm`, `destroyWindowRealm` (how, as `WindowRealmEnd`: `.global_detached` - its page is gone or a navigation replaced its Window, Blink kGlobalObjectIsDetached; `.navigable_destroyed` - HTML "destroy a child navigable", Blink kFrameIsDetached: the global stays attached, severed from the Window), `createWorkerRealm` (HTML "run a worker" step 5: `WorkerRealmOptions.global` picks the global object, a DedicatedWorkerGlobalScope or, for a shared worker, a SharedWorkerGlobalScope), `destroyWorkerRealm`, `currentRealm`, `entryRealm`, `incumbentRealm`, `functionRealm`, `installWindowOperations`, `defineBuiltinFunction` |
| Running script (HTML 8.1.4) | `runClassicScript`, `evaluateClassicScript`, `evaluateClassicScriptToString`, `compileEventHandler`, `prepareToRunScript` / `cleanUpAfterRunningScript`, `runInRealm`, `runTaskInRealm`, `performMicrotaskCheckpoint` and `queueMicrotask` (the agent's - an event loop's), `extractErrorInformation` |
| Modules [module_scripts] | `parseModule`, `parseJSONModule`, `createDefaultExportSyntheticModule` (ECMA-262 CreateDefaultExportSyntheticModule, for HTML "create a CSS module script"), `moduleRequests`, `linkModule`, `evaluateModule`, `finishDynamicImport`, `releaseModuleRecord` |
| Callbacks (WebIDL) | `invokeCallbackFunction`, `callUserObjectOperation`, `isCallable`, `isConstructor`, `takeCallbackFunction` / `takeCallbackInterface` (transitional) |
| ECMAScript values | `getProperty`, `setProperty`, `defineOwnProperty`, `hasProperty`, `typeOf`, `sameValue`, `toBoolean`, `retainValue`, `releaseValue`, `throwValue`, `completionOf`, `parseJsonToValue`, `serializeJsonToBytes` |
| WebIDL: ES to IDL | `convertToDOMString`, `convertToUSVString`, `convertToUnrestrictedDouble`, `convertToPlatformObject`, `convertToSequence*`, `convertToRecordOfStrings`, `getCopyOfBufferSourceBytes`, `iterate`, `getIterator`, `iteratorNext`, `iteratorReturn`, `iteratorResult`, `releaseIteratorRecord` |
| WebIDL: IDL to ES | `createSequenceOfValues`, `createSequenceOfPlatformObjects`, `createDictionaryObject`, `createObservableArray`, `createFrozenArray`, `createAsyncIterator` |
| Exceptions | `createSimpleException`, `createDOMException` |
| Promises | `createPromise`, `resolvePromise`, `rejectPromise`, `releasePromiseCapability`, `createResolvedPromise`, `createRejectedPromise`, `reactToPromise`, `markPromiseAsHandled`, `promiseIsHandled` [promise_rejection_tracking] |
| Buffers | `createArrayBuffer`, `allocateArrayBuffer`, `createArrayBufferView`, `describeArrayBufferView`, `writeIntoArrayBufferView`, `borrowArrayBufferBytes`, `isDetachedBuffer`, `canTransferArrayBuffer`, `transferArrayBuffer`, `getViewedArrayBuffer` |
| Structured serialization | `structuredSerializeForStorage`, `structuredDeserialize`, `structuredSerializeWithTransfer`, `structuredDeserializeWithTransfer` |
| Platform objects (engine concerns) | `hasWrapper`, `keepPlatformObjectAlive` / `releasePlatformObject` (pending activity - Blink's HasPendingActivity: a root while it lasts), `platformObjectDestroyed`, `traceChild` / `forgetTracedChild` (an owner keeps a child as `TracedSlot`, a member name: the child's wrapper lives exactly as long as the owner's - Blink's `Trace` of a `Member<>`; V8 draws it as a private property on the owner's wrapper, a Window's on its global object; an edge, never a root, so a pair that keep each other still go together) |
| Diagnostics (tools only) | `heapStatistics`, `writeHeapSnapshot`, `diagnosticCounters` |

### Host hooks

The host's side of the ECMAScript host hooks is a `HostHooks` value, installed
per agent by `createAgent` and nowhere else: `loadImportedModule`
(HostLoadImportedModule for `import()`, finished with `finishDynamicImport`),
`importMetaUrl` (HostGetImportMetaProperties steps 1-3, import.meta.url),
`importMetaResolve` (its steps 4-6: the engine makes the builtin
`import.meta.resolve` beside `url`, does its ToString, and asks the host to
resolve a module specifier given the module's realm and base URL - null is
the TypeError), `promiseRejectionTracker` (HostPromiseRejectionTracker, with
the rejection reason) and `afterMicrotaskCheckpoint` (HTML "notify about
rejected promises"). The Window host's hooks are `html/rejected_promises.zig`'s
`hooks` and `html/script_execution.zig`'s `module_hooks`; a worker's are
`html/worker_host.zig`'s `worker_hooks`. A hook whose capability the engine
lacks is never called. Every hook defaults to null; an adapter that does not
wire `importMetaResolve` (JavaScriptCore and QuickJS today, which have no
module hooks) leaves import.meta without `resolve`.

## 6. Adding an operation

An engine need that no operation meets becomes a new operation. Request it
from the integrator, who owns engine_protocol.zig. It lands in one change:

1. **The declaration**, in the facade's area, named after the spec concept it
   is (an ECMAScript abstract operation, a WebIDL or HTML algorithm) or, for
   an engine concern with no spec, after the concern. Its doc comment says
   who owns what it takes and returns, and when it fails. Realm first if it
   reads a value. Never a V8-shaped pass-through: it must be implementable on
   the JavaScriptCore C API, which is the test for a V8-shaped operation.
   Gated on a capability when an engine cannot provide it.
2. **The V8 implementation**, in the adapter (`protocol.zig` or the
   `protocol_*.zig` of its area), following the spec's steps with numbered
   comments. New V8 FFI goes in the protocol region blocks at the end of
   `v8_wrapper.cpp` and `ffi.zig`.
3. **The other adapters**: JavaScriptCore, QuickJS and the test adapter
   (`NotSupported`, or an answer by the IDL arm where no engine is needed).
4. **A tests/v8 test** of the V8 implementation, with values made the way the
   binding makes them; a leak check (live global-handle bytes flat over 32
   rounds) when it makes handles. A runtime-tier test (tests/runtime) when the
   engine-less adapters answer something.
5. **This file** updated (the operation table, and the capabilities if one
   was added).

## 7. Declared deviations (V8)

- `setProperty` is V8's sloppy Set: a [[Set]] that returns false does not
  throw the spec's TypeError.
- A `reactToPromise` on a promise that never settles keeps 32 bytes until
  process exit.
- No ByteString string conversion yet (Headers).
- An asynchronous iterator object gets a per-object prototype with no class
  string (a shared per-interface one needs the interface's identity).

## 8. Transitional pieces

- **The runtime Engine table** (`runtime.EngineInterface`, reached through
  `ctx.getEngine()`) is gone. The types it shared with the protocol are
  src/runtime/engine_types.zig's, and the runtime module imports the protocol
  itself (build.zig binds `engine` into runtime; a test tier gets a runtime of
  its own, bound to its adapter). Nothing of it is left: the last piece,
  `runtime.CallbackOperations`, went when callback interface arguments became
  borrowed for the call.
- **`takeCallbackFunction` / `takeCallbackInterface`** untag the binding's
  callback values until codegen types callback parameters as
  `CallbackFunction` / `CallbackInterface`. A `*runtime.CallbackWrapper` is
  an opaque, BORROWED argument: the binding releases it when the call
  returns, and an impl that keeps the callback takes its own
  CallbackInterface.
- **Ownership flags** are gone: `runtime.JSValue`'s handle arm is only the
  engine's pointer (it carried `needs_disposal` and a `.local` / `.global`
  tag). The binding releases every value an impl returns; the generated
  [SameObject] cache is not emitted for a `runtime.JSValue` getter, whose
  impl keeps its value and returns a hold of it.
