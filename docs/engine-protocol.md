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
| `Context` | A realm's identity (`runtime.Context`). BORROWED wherever it is a parameter; stable until the realm is torn down. A retired realm has no engine realm behind it. Work queued on the realm's own agent may keep a Context across turns: a torn-down realm's record stays valid and inert until its agent ends (the V8 adapter retires it, `context_manager` `retired`), and `hasEngine()` turns false at retirement. Keeping one is not a root. Check `hasEngine()` before each step that enters the realm, and pass operations only a live one; a retired one may only be compared. Precedent: `src/webcrypto/tasks.zig`. |
| `Agent` | An ECMAScript agent: a V8 isolate, a JSC context group. Opaque. |
| `JSValue` | The IDL-level value (`runtime.JSValue`). As a parameter, always BORROWED for the call. As an impl's RESULT, the binding's: it releases it once set. Its handle carries no ownership flag - the holder's type says who releases it. |
| `Instance` | A platform object: the host's side of a wrapper. It lives no longer than its realm: at the realm's end its wrapper cache frees every Instance it alone wraps (a node still in a tree excepted) and severs the wrapper. A traceChild edge or an Owned value roots the wrapper, not the Instance. So a pointer to an Instance kept across turns is valid only while its realm `hasEngine()`. Keep that realm's Context beside it and check it before every dereference, never through the Instance's own `ctx`. (Blink keeps a reachable object alive past its context; Crane does not yet: feature-queue "cross-realm Instance lifetime".) |
| `Owned` | A value the caller owns. Exactly one of `release()` (give it back) or `take()` (hand it, and the duty to release it, to something documented to take ownership - the binding, for an impl's result). `borrow()` lends it, BORROWED, while it is held - to an operation, never as an impl's result: a kept value is returned as `(try retainValue(realm, kept.value)).take()`. |
| `Completion` | ECMAScript's Completion Record from an operation that runs script: `normal` or `throw`, OWNED either way. |
| `CallbackFunction`, `CallbackInterface` | WebIDL's callback values: the function or object (OWNED) and the callback context (the incumbent realm when the value was converted). The invoke operations take them BORROWED. |
| `PromiseCapability` | WebIDL "a new promise": OWNED until `releasePromiseCapability`; its `promise` is a BORROWED view. |
| `ErrorInfo` | HTML "extract error information": BORROWED for the call it is handed to. `parse_error` says the reported exception is the script's PARSE ERROR (HTML "create a classic script": the script's parse error and error to rethrow), not what its evaluation threw - set by the classic-script operations; "run a worker" onComplete step 1 reads it (a worker whose script does not parse fires a plain `error` at its Worker and runs nothing). |
| `Reporter` | HTML "report an exception", as the host supplies it to an operation that runs script. |
| `ModuleRecord`, `IteratorRecord`, `ImportRequest` | Opaque, OWNED until their release or finish operation. |

Slices an operation returns are allocated with the allocator the caller
passed, and are the caller's. Every operation that reads a value takes the
realm first.

**An instance's teardown never runs while the engine is collecting.** When the
collector takes a platform object's wrapper, the adapter makes the instance
unreachable through the binding at once - a later wrap makes a new wrapper -
and defers its teardown (the vtable `deinit` and everything it releases) to a
point where engine calls are allowed, so a deinit may release `Owned` values,
end holds and edges, and call any operation. An instance wrapped again in
between is not torn down: the new wrapper owns it. V8: the first pass of its
weak callbacks only unlinks the wrapper cache's entry, and the instance is
torn down in the second pass (`SetSecondPassCallback`; v8-weak-callback-info.h:
"No v8 other api calls may be called in the first callback"), as Blink's
ScriptWrappable did. JavaScriptCore's `JSObjectFinalizeCallback` and QuickJS's
class finalizer run inside their collectors, so those adapters queue the
teardown the same way once they wrap platform objects; today they wrap none.
`AsyncIteratorSteps.finalize` runs under the same rule.

**A realm's end finalizes what no wrapper owns.** The host data behind a
promise reaction that has not run (`PromiseReactionSteps.dropped`) and behind
an asynchronous iterator still alive (`AsyncIteratorSteps.finalize`) is freed
when the reaction or iterator ends: settled, collected, or - whichever comes
first - its realm's end, before the realm's objects are torn down. After that
a reaction function or an iterator method script still reaches (from another
realm's promise, from another realm's variable) does nothing, or rejects with
a TypeError; it never reaches the freed data. V8: the reaction functions'
[[data]] is a one-slot holder array whose External points at the adapter's
record, which keeps a WEAK handle of the holder (strong would keep the realm
alive) armed with a second-pass finalizer, and sits on its realm's list
(realm_finalizers.zig, on the realm's WrapperCache); the realm's end
(context_manager.removeContextByKey) clears each holder's slot, disposes the
handle - cancelling a second pass still to come - and runs `dropped`. An
iterator's record is the same over its state array. JavaScriptCore: the
reaction functions are JSObjectMake objects of a JSClass with
`callAsFunction` and a private record, attached with
`JSObjectCallAsFunction(promise.then, ...)`; a per-realm list is drained at
`destroyWindowRealm` / `destroyWorkerRealm`, `JSObjectSetPrivate(fn, NULL)`
disarming each function, and the class's `finalize` - which runs inside the
collector - only queues the record for `dropped` at the next point where
engine calls are allowed. QuickJS: `JS_NewCFunctionData` functions and a
class finalizer, the same way. Both answer `reactToPromise` with
`NotSupported` today: no step and no `dropped` ever runs, and the data stays
the caller's.

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
- **Threads:** an agent is used only on the thread that made it - every
  operation that takes the agent, or a realm or value of it, runs there. The
  one exception is `abortRunningScript`, which may be called from any thread
  for as long as the agent lives (the host serialises it against the agent's
  end with a lock of its own: html/worker_link.zig's `agent_lock`).
  `destroyAgent` runs on the agent's thread. Each worker makes its agent on a
  thread of its own with no other agent entered there, so that agent is its
  thread's host agent (`AgentRecord.host_agent`), and its end takes the
  thread's engine state down with it. A worker realm records its own event
  loop (`WorkerRealmOptions.event_loop`, required: every worker - dedicated
  and shared - runs its own loop on its own thread, so no worker realm is
  without one) as a window realm does; the engine stores it and never runs
  it.

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
| `script_abort` | native (TerminateExecution) | unsupported - no public way to end a running script (JSContextGroupSetExecutionTimeLimit is SPI) | a script that never returns holds its agent's thread; the host's bound is outside the process (the WPT runner's stall watchdog) |
| `code_generation_checks` | native (ModifyCodeGenerationFromStringsCallback, AllowWasmCodeGenerationCallback) | unsupported - no hook before eval, the Function constructor or WebAssembly compilation compiles | the HostHooks below are never called: eval, Function and WebAssembly compile unchecked - CSP's 'unsafe-eval' / 'wasm-unsafe-eval' and Trusted Types' eval sink go unenforced (security-relevant) |
| `html_constructor` | native (the construct callback's FunctionCallbackInfo::NewTarget) | unsupported - a JSObjectCallAsConstructorCallback is handed no NewTarget, so `super()` from a custom element class cannot reach the host | `HostHooks.htmlConstructor` is never called: HTMLElement and the other [HTMLConstructor] interfaces construct as their own constructors do, so custom element construction - `new MyElement()`, createElement of a defined name, an upgrade - is unavailable on iOS until JavaScriptCore's C API offers NewTarget |

Flip a JavaScriptCore capability when an iOS release makes the API public.
Structured serialization has no JSC API and is not a capability: the JSC
adapter will use Crane's own walker (src/html/structured_clone).

## 5. Operations

`engine_protocol.zig` groups them; each group names the spec it follows.

| Area | Operations |
|---|---|
| Engine and agents | `initializeEngine`, `deinitializeEngine`, `createAgent` (with the host's `HostHooks`), `destroyAgent`, `hasRunningScript`, `hasPendingEngineWork`, `runEngineTasks`, `notifyMemoryPressure` (a page let go: `.critical`; a hint: `.moderate`), `agentHost` (the AgentOptions.host pointer the agent was made with, handed back; null once destroyed), `requestGarbageCollection` (testing only), `abortRunningScript` [script_abort] (HTML 8.1.4.5 "abort a running script", from any thread: a resource limit's abort "without an exception") and `resumeScripts` [script_abort] (the agent may run script again) |
| Realms | `createWindowRealm`, `destroyWindowRealm` (how, as `WindowRealmEnd`: `.global_detached` - its page is gone or a navigation replaced its Window, Blink kGlobalObjectIsDetached (a frame realm a navigation replaced is detached and ends once collected or with its page); `.navigable_destroyed` - HTML "destroy a child navigable", Blink kFrameIsDetached: the global stays attached, severed from the Window), `createWorkerRealm` (HTML "run a worker" step 5: `WorkerRealmOptions.global` picks the global object, a DedicatedWorkerGlobalScope or, for a shared worker, a SharedWorkerGlobalScope), `destroyWorkerRealm`, `currentRealm`, `entryRealm`, `incumbentRealm`, `functionRealm`, `installWindowOperations`, `defineBuiltinFunction` |
| Running script (HTML 8.1.4) | `runClassicScript`, `evaluateClassicScript`, `evaluateClassicScriptToString`, `compileEventHandler`, `prepareToRunScript` / `cleanUpAfterRunningScript`, `runInRealm`, `runTaskInRealm`, `performMicrotaskCheckpoint` and `queueMicrotask` (the agent's - an event loop's; no dropped end, so host data that must be freed goes through `queueRealmMicrotask`), `extractErrorInformation`, `runningScriptLocation` (CSP 2.4.1 step 2: the agent's running script's URL - its `//# sourceURL=` for eval and Function code - and 1-based line and column, as a `ScriptLocation` whose URL the caller owns; null when no script runs. V8: StackTrace::CurrentStackTrace's top frame. JavaScriptCore and QuickJS: always null - violations carry no source location there; JSContextCreateBacktrace, public, is the JavaScriptCore route to a URL and line) |
| Modules [module_scripts] | `parseModule`, `parseJSONModule`, `createDefaultExportSyntheticModule` (ECMA-262 CreateDefaultExportSyntheticModule, for HTML "create a CSS module script"), `moduleRequests`, `linkModule`, `evaluateModule`, `finishDynamicImport`, `releaseModuleRecord` |
| Callbacks (WebIDL) | `invokeCallbackFunction`, `constructCallbackFunction` (WebIDL "construct a callback function", for custom element constructors: IsConstructor false is a throw completion of a new TypeError; otherwise Construct(F, args) in F's realm with the callback context as the incumbent, the object or the throw handed back as a Completion - there is no exception behavior. A constructed platform object comes back as its wrapper. An *Instance result does not root a wrapper. An impl that holds an element's wrapper only through an Owned - a custom element constructed here, say - keeps that Owned (or another hold of its own) until the caller has the value; between the impl's return and the binding wrapping the result, [CEReactions] end() can run script and so GC. `keepPlatformObjectAlive` is one per-instance flag shared by every owner (pending activity), so it cannot carry a second, independent reason. JavaScriptCore - JSObjectCallAsConstructor - and QuickJS - JS_CallConstructor - NotSupported until linked, as is the test adapter), `callUserObjectOperation`, `isCallable`, `isConstructor`, `takeCallbackFunction` / `takeCallbackInterface` (transitional) |
| ECMAScript values | `getProperty`, `setProperty`, `defineOwnProperty`, `hasProperty`, `hasOwnProperty` (ECMAScript HasOwnProperty; a Proxy trap's throw surfaces as ExceptionPending), `typeOf`, `thisTimeValue` (a Date's [[DateValue]] or null; never runs script), `isArrayExoticObject` (not IsArray: a Proxy of an array is not one), `createDate` (TimeClip),  `sameValue`, `toBoolean`, `retainValue`, `releaseValue`, `throwValue`, `completionOf`, `withPendingExceptionSetAside(agent, steps, data)` (for HTML [CEReactions]: the bracket's end runs the popped queue's reactions as `steps` with the exception the member left pending set aside, and the same value is pending again after - agent-scoped, so no realm and no exception value crosses the seam; steps must leave nothing pending, and what they do leave is cleared. V8 sets aside what the innermost binding catch scope holds - the binding dispatches every member a generated interface lists in `ce_reactions` in one, as Blink's CEReactionsScope holds a v8::TryCatch - and makes it pending again inside that scope; one pending outside a scope, a [CEReactions] member reached from Zig, is NotSupported and the steps do not run: it stays pending, and end moves the queue's elements to the backup element queue instead; ExceptionPending while terminating. JavaScriptCore and QuickJS: no engine linked, nothing is pending, the steps run - linked, JSC stashes and restores its adapter's pending slot and QuickJS uses JS_GetException / JS_Throw; the test adapter runs the steps), `parseJsonToValue`, `parseJsonInNewGlobal` (ECMAScript JSON.parse "in the context of a new global object", WebCrypto "parse a JWK": a new global's intrinsics, so the caller's prototypes do not show through; a SyntaxError is the caller's; NotSupported in QuickJS and the test adapter), `serializeJsonToBytes` |
| WebIDL: ES to IDL | `convertToDOMString`, `convertToUSVString`, `convertToUnrestrictedDouble`, `convertToPlatformObject`, `convertToSequence*`, `convertToRecordOfStrings`, `getCopyOfBufferSourceBytes` (BufferSource, not [AllowShared]: a SharedArrayBuffer is null, a view over one a TypeError), `getCopyOfAllowSharedBufferSourceBytes` (AllowSharedBufferSource: an ArrayBuffer, a SharedArrayBuffer or a view over either), `iterate`, `getIterator`, `iteratorNext`, `iteratorReturn`, `iteratorResult`, `releaseIteratorRecord` |
| WebIDL: IDL to ES | `createSequenceOfValues`, `createSequenceOfPlatformObjects`, `createDictionaryObject`, `createObservableArray`, `createFrozenArray`, `createAsyncIterator` |
| Exceptions | `createSimpleException`, `createDOMException` |
| Promises | `createPromise`, `resolvePromise`, `rejectPromise`, `releasePromiseCapability`, `createResolvedPromise`, `createRejectedPromise`, `reactToPromise` (for each call that succeeded, exactly ONE of the steps' `fulfilled`, `rejected` and `dropped` runs, once: `dropped` when the reaction ends without a step - the promise settled the way no step is given for, or the engine dropped it pending: its realm ended (before the realm's objects are torn down), the collector took the promise with it, or the agent ended; it frees the host's data, never runs script and never runs inside a collection; on an ended realm the call fails and the data stays the caller's), `queueRealmMicrotask` (HTML "queue a microtask" whose steps belong to a realm, with the same exactly-once terminal contract: `fulfilled` at the agent's next checkpoint, FIFO with every other microtask, or `dropped` - at the realm's end (before its objects are torn down; an agent's realms end before it), or after the collector takes a job whose queue was discarded (a terminated checkpoint), on the agent's thread and never inside a collection. No checkpoint runs inside the call: V8 suppresses automatic checkpoints around creating the fulfilled promise and registering its reaction. New code that hands the engine host data with a microtask uses this, not `queueMicrotask`: `queueMicrotask` has NO dropped end, and its data leaks when its microtask never runs. JSC and QuickJS currently answer NotSupported), `markPromiseAsHandled`, `promiseIsHandled` [promise_rejection_tracking] |
| Buffers | `createArrayBuffer`, `allocateArrayBuffer`, `createArrayBufferView`, `describeArrayBufferView`, `writeIntoArrayBufferView`, `borrowArrayBufferBytes`, `isDetachedBuffer`, `canTransferArrayBuffer`, `transferArrayBuffer`, `getViewedArrayBuffer` |
| Structured serialization | `structuredSerializeForStorage`, `structuredDeserialize`, `structuredSerializeWithTransfer`, `structuredDeserializeWithTransfer`. A platform object whose PRIMARY interface is [Serializable] and has steps (its generated interface's `serializable_steps`, by identifier) is written as the identifier, the engine-neutral `SerializationRecord` its serialization steps fill (forStorage true only for ...ForStorage) and its sub-serializations - serialized with the same memory as the rest of the value - and read back as a new instance in the target realm set up by its deserialization steps (`DeserializationRecord`); any other platform object throws DataCloneError. Everything is inline (a Blob's bytes are copied), so the bytes cross agents, threads and IndexedDB. V8: the ValueSerializer/ValueDeserializer delegates' WriteHostObject/ReadHostObject (serializable_objects.zig); JavaScriptCore's walker would call the same steps |
| Platform objects (engine concerns) | `hasWrapper`, `keepPlatformObjectAlive` / `releasePlatformObject` (pending activity - Blink's HasPendingActivity: a root while it lasts), `platformObjectDestroyed`, `traceChild` / `forgetTracedChild` (an owner keeps a child as `TracedSlot`, a member name: the child's wrapper lives exactly as long as the owner's - Blink's `Trace` of a `Member<>`; V8 draws it as a private property on the owner's wrapper, a Window's on its global object; an edge, never a root, so a pair that keep each other still go together. It never makes the OWNER's wrapper: an owner script has not seen holds the child strongly until its wrapper is made - the edge is drawn on it then - and ends that hold with `forgetTracedChild` in its teardown if it is freed unwrapped. It DOES make the child's wrapper, and from then on the collector frees the child with that wrapper unless something else owns it natively - a node's tree, a live template's contents (`dom.template_contents.ownedByLiveTemplate`): never trace to a child only native code holds, such as a template from its content, which made the template collectable and let a constructor's receiver replace its wrapper (PR-M1). A constructed instance that its construction already wrapped keeps that wrapper as the construction's result - the adapter never replaces a live wrapper - so the edges drawn on it stay), `traceValue` / `tracedValue` (the same edge for a JavaScript VALUE an owner keeps for script - a CustomEvent's detail, a FileReader's result, a NavigateEvent's info: Blink's `TraceWrapperV8Reference`; any value, a primitive too, in `traceChild`'s slot namespace, read back as an `Owned` the caller releases - null when there is none - and ended with `forgetTracedChild`. JavaScriptCore would use a private-symbol property on the owner's object; the JSC, QuickJS and test adapters keep nothing and read null) |
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
rejected promises"), and [code_generation_checks] `ensureCanCompileStrings`
(HostEnsureCanCompileStrings: eval and the Function constructors, told the
`StringCompilation` - compilation type, codeString, whether every argument
is code-like - and answering allowed or blocked, blocked being the EvalError
the engine throws), `getCodeForEval` (HostGetCodeForEval: a TrustedScript
argument's code) and `ensureCanCompileWasmBytes`
(HostEnsureCanCompileWasmBytes: false is a WebAssembly.CompileError), and
[html_constructor] `htmlConstructor` (HTML 3.2.3 "HTML element constructors"
for an [HTMLConstructor] interface, its generated `Meta.html_constructor`: the
engine does step 1 and steps 10-11, 14 and 16, the host steps 2-9, 12, 13 and
15, given the current realm, NewTarget BORROWED and the active function's
interface; it answers `HTMLConstructed` - `.created`, a new element OWNED and
handed to the engine to wrap with NewTarget's prototype, or `.upgrading`, the
construction stack's element BORROWED, whose wrapper - the one it has or a new
one - gets NewTarget's prototype and is the construction's result; no hook
installed, the interface constructs as its own constructor does. V8 gets
NewTarget's prototype when it makes the receiver, before step 1, as Blink's
V8HTMLConstructor does). Every
eval and Function call in a realm of an agent with `ensureCanCompileStrings`
costs one host call: V8 asks only contexts that disallow code generation
from strings, so every realm of such an agent disallows it, whether or not
a policy exists yet (Blink instead disallows it when a policy without
'unsafe-eval' arrives). The Window host's hooks are
`html/rejected_promises.zig`'s `hooks`, `html/script_execution.zig`'s
`module_hooks` and `html/code_generation.zig`'s `hooks`; a worker's are
`html/worker_host.zig`'s `worker_hooks` (not yet the code generation ones). A hook whose capability the engine
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
- No ByteString string conversion yet (Headers).
- An asynchronous iterator object gets a per-object prototype with no class
  string (a shared per-interface one needs the interface's identity).
- V8's code generation callback names no compilationType: the adapter reads
  CreateDynamicFunction's source shape - `(function anonymous(`,
  `(async function anonymous(`, `(function* anonymous(` or
  `(async function* anonymous(` ... `\n})` - as a constructor's, its outer
  parentheses stripped to ECMA-262's sourceString, and anything else as
  eval's. An eval of a string of exactly that shape is reported as a
  constructor's.
- `arguments_are_code_like` is V8's is_code_like: true only for objects whose
  template is SetCodeLike, which TrustedScript's is not yet - so a Function
  constructor given TrustedScripts is checked as one given strings (eval of
  a TrustedScript is exact, through `getCodeForEval`). V8 also says
  is_code_like for a Function constructor given no arguments at all.

## 7a. Declared differences between adapters

- `ErrorInfo.parse_error` - V8: set when the classic script failed to compile
  (protocol_scripts.zig, the compile-failed path of runClassicScript and
  evaluateClassicScript*). JSC/QuickJS: always false - a worker whose
  top-level script fails to parse is reported as a runtime error would be
  ("run a worker" onComplete step 1 not distinguished). The route there:
  JavaScriptCore's `JSCheckScriptSyntax` on the error path; QuickJS a
  compile-only `JS_Eval` (`JS_EVAL_FLAG_COMPILE_ONLY`) before running. The
  runtime tier's test adapter reports every non-empty script as its parse
  error (it parses nothing), so host code can be driven through the path.

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
