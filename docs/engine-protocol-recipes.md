# Engine protocol recipes

How to move code off V8 onto the engine
protocol, `@import("engine")` (src/runtime/engine_protocol.zig). One recipe
per intent - what the code was trying to do - with the V8 pattern it replaces,
the protocol call, who owns what, the pitfalls, and a before/after. The
protocol itself is described in [engine-protocol.md](engine-protocol.md); the
rules that bind every change are in AGENTS.md, "The engine boundary".

"Seen in" names files where the pattern was found when the recipes were
written; most of them have migrated since, and are now the models to copy.

A migrated file has **zero V8 references and zero table calls**: no
`@import("v8")`, no `v8_*`, no `ffi`, no `ctx.getEngine()` / `engine.op.?()`
table reach. Then `zig build lint-engine -j2 --cache-dir /tmp/crane-z16-cache
-- --update` records the drop (the baseline only goes down).

---

## 0. Rules every recipe assumes

### 0.1 Import and module wiring

```zig
const engine = @import("engine");
```

Modules that have the import today: `impls` (src/webidl/impls), `html`,
`browser`, `lib_exports`, the tools that run script (tools/repl.zig,
tools/gc_bench.zig, the WPT runner) and the tests/v8 targets (tests/runtime
binds the test adapter through build.zig's `engineProtocolBinding`). A file in any
other module (dom, fetch, streams, ...) needs build.zig wiring first
(`<mod>.addImport("engine", engine_mod)`) - ask the integrator for it rather
than importing `v8`.

### 0.2 The name `engine` is taken - a file converts fully, or renames

`const engine = @import("engine")` collides with every local
`const engine = ctx.getEngine() orelse ...`. Zig forbids the shadowing, so a
file either converts all its table calls in the same commit, or renames the locals first
(`const table = ctx.getEngine() orelse ...`). Never keep both the import and
a local named `engine`. A test file that already names the table `engine`
imports the protocol as `const protocol = @import("engine");`
(tests/v8/engine_runtime_impls_operations_test.zig does).

### 0.3 Ownership vocabulary (the types ARE the rule)

| Thing | Rule |
|---|---|
| `JSValue` parameter | BORROWED for the call. Never release it, never store it. |
| `realm: Context` parameter | BORROWED; outlives the call. |
| `engine.Owned` result | The caller's. Exactly one of `.release()` (give it back) or `.take()` (hand it, and the duty to release, to something documented to take ownership - the binding, when an impl returns it). |
| `Owned.borrow()` | A BORROWED view of a value its holder keeps: what a getter returns for a stored value. The binding reads it and never releases it. |
| `engine.Completion` | `union { normal: Owned, throw: Owned }` - both arms OWNED; release the arm you get (`switch (c) { inline else => |v| v.release() }`). |
| `engine.CallbackFunction` / `CallbackInterface` | OWNED (`.release()`), with the callback context (the incumbent realm at conversion) inside. The invoke operations take them BORROWED (`*const`). |
| `PromiseCapability` | OWNED (`releasePromiseCapability`); `.promise` is a BORROWED view until then. |
| `[]u8` / slices from conversions | OWNED by the `allocator` you passed. |
| `ErrorInfo` given to a `Reporter` | BORROWED for the call; copy what you keep. `error_value` BORROWED. |

`engine.retainValue(realm, v)` returns `undefined`, `null`, booleans and
numbers BY VALUE (no engine resource; no realm entered, so a realm without an
engine will do); strings, objects and platform objects become a handle of the
caller's own.

### 0.4 A `.handle` from the binding is a Global, whatever its tag says

The binding hands an impl object/function values (arguments, dictionary
members) as `JSValue.handle` whose `handle_scope` is `.local` - but the
pointer is ALWAYS a `Global<Value>*` the binding owns ("One handle kind per
layer"; docs/lessons/architecture-a-local-tagged-handle-is-a-borrowed-global.md).
`.local` means "borrowed for the call", nothing more. So:
- never read it as a Local slot (`v8_Value_ToGlobal`, `*_Local` FFI) - that is
  how `new ErrorEvent("x", {error: obj}).error` became a garbage number;
- never dispose it;
- to keep it past the call: `engine.retainValue(realm, value)`.

### 0.5 Which realm to pass

| Situation | Realm |
|---|---|
| Making an operation's or getter's RESULT (arrays, promises, dictionaries) | the current realm: `engine.currentRealm() orelse instance.ctx` (WebIDL converts results in the current realm) |
| Holding / converting an `.instance` | any realm of its agent: every protocol operation converts a platform object to its wrapper in its RELEVANT realm (`instance.ctx`), whichever realm it entered (engine-protocol.md, "Realms"; protocol_support.relevantWrapper). Pass `instance.ctx` anyway where the op makes nothing else. |
| An object's own stored state (an event's `any` member, a callback) | the object's relevant realm, `instance.ctx` (or the constructor's `ctx`) |
| Invoking a stored callback | any realm of its agent - the observer's / target's `ctx`; the call itself runs in the callback's associated realm |
| A task or microtask of a global | that global's `ctx` |

`engine.currentRealm()` is null when no script is running; it is never
"whatever context V8 has current" outside a call.

### 0.6 Errors

`engine.Error = { OperationFailed, ExceptionReported, OutOfMemory, TypeError, ExceptionPending, DataCloneError, NotSupported }`.
- `TypeError`: the spec throws a TypeError and nothing is thrown yet - return
  it; the binding throws it.
- `ExceptionPending`: script (or the engine for the spec) threw; it is pending
  - return it and throw nothing else.
- `ExceptionReported`: script threw and the operation already reported it
  through its Reporter; nothing is pending.
- `NotSupported`: the engine lacks the operation (a declared capability, or a
  realm with no engine behind it - a DOM unit test).
- Never `catch {}` an engine error silently. Propagate it, or name why the
  fallback is right (the MutationObserver notify fallback below).

### 0.7 Capability-gated operations

`if (engine.capabilities.X != .unsupported) engine.op(...)` - comptime, so the
call compiles out where the engine lacks X. Calling a gated op outside such a
branch is a compile error naming the capability. Gated today:
`promiseIsHandled` (`promise_rejection_tracking`), the module ops
(`module_scripts`), `functionRealm` (`exact_function_realm`), the diagnostics
tier.

### 0.8 Engine values belong to the instance, not its Zig state

Keep engine values (`engine.Owned`, callbacks) out of a Zig `InternalState`
whose `init`/`deinit` a test without V8 exercises (tests/cookiestore,
tests/url, tests/xhr link no engine): release them in the impl's instance
`deinit`, before the Zig state's own. A type reference to `engine.Owned`
costs nothing; a call to `release()` from code such a test reaches links the
engine. (The facade itself compiles an engine adapter's functions only as
they are called - `links_engine` - so reaching the facade is not enough to
need V8.)

---

## 1. Table-era operations: `ctx.getEngine().op.?(...)` -> `engine.op(...)`

The Engine table (`runtime.EngineInterface`, now deleted - this section maps
its operations for code that still reads like it) took `engine_ctx:
*anyopaque` and untyped values in its oldest entries; the
protocol takes `realm: Context` first and `JSValue` / `Owned`. Replace

```zig
const eng = ctx.getEngine() orelse return error.NoEngine;
const f = eng.createResolvedPromise orelse return error.NotSupported;
const p = try f(ctx, value);
return p;
```

with

```zig
return (try engine.createResolvedPromise(ctx, value)).take();
```

| Table field | Protocol | Notes |
|---|---|---|
| `wrapAsyncIterator(engine_ctx, zig_iterator)` | `createAsyncIterator(realm, *const AsyncIteratorSteps, data) Error!Owned` | steps `next`/`return`/`finalize` (R37) |
| `createPromise(engine_ctx, allocator)` | `createPromise(realm) Error!PromiseCapability` | R16 |
| `getPromiseObject(handle)` | `capability.promise` | BORROWED view; `retainValue` to keep |
| `resolvePromise(engine_ctx, handle, ?*const anyopaque)` | `resolvePromise(*PromiseCapability, JSValue) Error!void` | `.instance` resolves with its wrapper |
| `rejectPromise(engine_ctx, handle, anyerror)` | `rejectPromise(*PromiseCapability, JSValue) Error!void` | make the reason with `createSimpleException` / `createDOMException` (R19) |
| `resolvePromiseWithInstance(handle, instance)` | `resolvePromise(cap, .{ .instance = x })` | |
| `rejectPromiseWithValue(handle, value)` | `rejectPromise(cap, value)` | |
| `destroyPromiseHandle(handle, allocator)` | `releasePromiseCapability(*PromiseCapability)` | |
| `createResolvedPromise(realm, v)` / `createRejectedPromise(realm, r)` | same names, `Error!Owned` | R15 |
| `chainPromiseHandlers(engine_ctx, p, cb, ctx, cb, ctx)` | `reactToPromise(realm, promise, *const PromiseReactionSteps, data) Error!void` | steps take `(data, value BORROWED)` (R17) |
| `markPromiseAsHandled(handle)` | `markPromiseAsHandled(realm, promise: JSValue) void` | any promise value (R18) |
| `createString(engine_ctx, bytes)` | none - pass `JSValue.fromStringRef(bytes)`; `retainValue` to hold | DROPPED |
| `isString(v)` / `extractString(engine_ctx, v, a)` | `JSValue.string` arm, or `convertToDOMString(realm, v, a)` | DROPPED |
| `getPropertyBoolean` / `getPropertyTruthy` | facade helper `engine.getPropertyBoolean(realm, obj, name) Error!?bool` (Get, then ToBoolean unless undefined); `(try ...) orelse default` for truthy | R23 |
| `getPropertyInstance` | facade helper `engine.getPropertyPlatformObject(realm, obj, name) Error!?*Instance` (null when undefined, TypeError when not a platform object) | R23 |
| `setPropertyOnObject(engine_ctx, target, name, string)` | `setProperty(realm, object, name, value) Error!void` | R23 |
| `defineOwnPropertyOnObject(engine_ctx, target, name, value)` | `defineOwnProperty(realm, object, name, value, PropertyAttributes) Error!void` | R23 |
| `parseJson(engine_ctx, str)` | `parseJsonToValue(realm, bytes) Error!Owned` | Infra "parse JSON bytes"; a BOM is dropped |
| `wrapInstance(engine_ctx, instance)` | none - return `JSValue.fromInstance(x)` / pass `.{ .instance = x }` | relevant-realm rule (R28) |
| `convertJSValueToEngine(engine_ctx, v)` | none - adapter-internal | DROPPED |
| `createStringArray(engine_ctx, strings)` | `createSequenceOfValues(realm, values) Error!Owned` | values `.string` (R12) |
| `createArrayBuffer(engine_ctx, bytes)` | `createArrayBuffer(realm, bytes) Error!Owned` | R25 |
| `createUint8Array(engine_ctx, bytes)` | `createArrayBuffer` + `createArrayBufferView(realm, .uint8, buffer, 0, len)` | R25 |
| `createEventLoop` / `destroyEventLoop` | none - the host's event loop | DROPPED |
| `createCallbackWrapper` / `invokeCallback` / `destroyCallbackWrapper` | `takeCallbackInterface` / `callUserObjectOperation` / `.release()` | R3, R5 |
| `invokeStreamCallback(engine_ctx, cb, controller, arg)` | `invokeCallbackFunction(realm, &cb, this, args, .rethrow)` | R4 |
| `requestGarbageCollection(engine_ctx)` | `requestGarbageCollection(agent: *Agent) void` | `realm.agent orelse ...` (TestUtils) |
| `scheduleOnMainThread` | none - the host task queue | DROPPED |
| `getWrapperForInstance(engine_ctx, cache, instance)` | `hasWrapper(instance) bool` | R27 |
| `compileScript` / `runScript` / `disposeScript` | `evaluateClassicScript` / `runClassicScript` | R30, R31 |
| `runClassicScript(realm, utf8, url, report, host)` | `runClassicScript(realm, ScriptSource, url, host_defined, Reporter) Error!void` | `.{ .utf8 = src }`; Reporter replaces the fn+host pair; `host_defined` is the script import() names as referrer (R31) |
| `performMicrotaskCheckpoint(realm)` | same, `Error!void` | R10 |
| `runTaskInRealm` / `runInRealm` | same | R8 |
| `createDOMException(realm, name, msg)` | same, `Error!Owned` | R19 |
| `createSimpleException(realm, kind, msg)` | same, `Error!Owned`; kinds gain `SyntaxError` | R19 |
| `structuredSerializeForStorage` / `structuredDeserialize` / `...WithTransfer` | same names | `structuredDeserialize*` return `Owned` (R26) |
| `createSequenceOfPlatformObjects(realm, instances)` | same, `Error!Owned` | R11 |
| `createFrozenArrayOfPlatformObjects(realm, instances)` | `createFrozenArray(realm, values: []const JSValue)` | `.{ .instance = x }` per item (R13) |
| `relevantGlobalObject(instance)` | the realm record: `instance.ctx.getRealm().?.global_object` | R7 |
| `releaseValue(v: JSValue)` | `releaseValue(Owned)` / `owned.release()` | |
| `retainValue(realm, v) JSValue` | `retainValue(realm, v) Error!Owned` | primitives by value now |
| `throwValue(realm, v)` | same | R20 |
| `invokeCallbackFunction(realm, cb: JSValue, this, args, report, host)` | `invokeCallbackFunction(realm, *const CallbackFunction, CallbackThis, args, ExceptionBehavior) Error!Completion` | R4 |
| `callUserObjectOperation(realm, *CallbackWrapper, op, args) JSValue` | `callUserObjectOperation(realm, *const CallbackInterface, op, CallbackThis, args, ExceptionBehavior) Error!Completion` | R5 |
| `takeCallbackFunction(argument) JSValue` | `takeCallbackFunction(argument) CallbackFunction` | records the callback context (R2) |
| `installWindowOperations` / `createObservableArray` / `queueMicrotask` / `createDictionaryObject` / `currentRealm` / `defineBuiltinFunction` | same names | |
| `describeArrayBufferView(v)` / `writeIntoArrayBufferView(view, bytes, off)` | same, realm first | R25 |
| `convertToUnrestrictedDouble` / `convertToDOMString` / `convertToUSVString` / `convertToPlatformObject` / `convertToSequenceOf{PlatformObjects,DOMStrings}` / `convertToRecordOfStrings` / `getCopyOfBufferSourceBytes` / `createSequenceOfValues` | same names | |
| `convertToSequenceOfObjects(realm, v, a) []JSValue` | same, `Error![]Owned` | release each, free the slice |
| `compileModule` / `runModule` / `runModuleAsync` / `hasTopLevelAwait` / `disposeModule` | `parseModule` / `linkModule` / `evaluateModule` / `releaseModuleRecord` | R33 |
| `freeze` / `thaw` / `isFrozen` | none (not in the protocol) | find the callers first |
| `invokeForEach` / `getCollectionLength` / `getCollectionElement` | `iterate(realm, value, IterateSteps, data) Error!bool` | R22 |
| `createAgent()` / `destroyAgent` | `createAgent(AgentOptions)` / `destroyAgent` | R35 |
| `hasRunningScript` / `hasPendingEngineWork` / `runEngineTasks` | same | |
| `createWorkerRealm(agent, options)` / `destroyWorkerRealm` | same, options by pointer | |
| `isCallable(value)` | `isCallable(realm, value)` | R24 |
| `keepPlatformObjectAlive(instance)` / `releasePlatformObject(instance)` | same | R27 |

---

## 2. Recipes

Each recipe: **Intent** (spec concept or engine concern) - **V8 pattern** as it
appears in the code - **Protocol** - **Ownership** - **Pitfalls** - a tiny
before/after. `ctx`/`realm` are `runtime.Context`.

### R1. Hold an `any` value past the call (event attributes, stored values)

Seen in: PromiseRejectionEvent, CustomEvent, ErrorEvent, rejected_promises,
CookieChangeEvent, ExtendableCookieChangeEvent, History, streams_js.

- **Intent**: an attribute "must return the value it was initialized to" (the
  object keeps an ES value), or host state holding a value across turns.
- **V8 pattern**: a local `retainValue` switch - `v8_Null`, `v8_Boolean_New`,
  `v8_Number_New`, `v8_String_NewFromUtf8`, `v8_Global_Clone`, and
  `.instance => null` - stored as `?*v8.ffi.Value`, disposed with
  `v8_Global_Dispose`, returned with `fromHandleNonOwning`.
- **Protocol**: `engine.retainValue(realm, value) Error!Owned` to hold;
  `owned.borrow()` to return it from a getter; `owned.release()` in deinit.
- **Ownership**: the argument is BORROWED (the conversion's); the Owned is the
  object's.
- **Pitfalls**:
  - The old `.instance => null` dropped a platform object to `undefined`.
    `retainValue` wraps it - pass its relevant realm (`value.instance.ctx`).
  - Store `null` for `undefined` only if undefined is the attribute's initial
    value; a dictionary default (`CustomEventInit.detail = null`) is applied
    by the impl - the generated dictionary's Zig `null` means "not present"
    (and, today, also a member PRESENT as JS null: section 3, gap 2).
  - Return `borrow()`, never `take()`, from a getter of a kept value - `take`
    hands ownership to the binding, which then releases what you still hold.
  - A getter that makes a NEW value each read (a fresh array) returns
    `.take()` instead; returning a fresh handle as non-owning is the
    CookieChangeEvent leak.
- **Before/after**:

```zig
// before
promise: ?*v8.ffi.Value = null,
internal.promise = retainValue(init.promise);          // local V8 switch
return runtime.JSValue.fromHandleNonOwning(internal.promise.?);
if (internal.promise) |v| v8.ffi.v8_Global_Dispose(v);

// after
promise: ?engine.Owned = null,
internal.promise = try hold(ctx, init.promise);
return internal.promise.?.borrow();
if (internal.promise) |v| v.release();

/// The event's own hold on `value`, or null for undefined.
fn hold(realm: runtime.Context, value: runtime.JSValue) !?engine.Owned {
    if (value == .undefined) return null;
    return try engine.retainValue(if (value == .instance) value.instance.ctx else realm, value);
}
```

### R2. Take a callback-function argument or dictionary member

Seen in: IntersectionObserver, MutationObserver, streams_writable,
WindowOrWorkerGlobalScope, EventTarget.

- **Intent**: WebIDL "converted to a callback function type": keep the
  function and its callback context.
- **V8 pattern**: `@ptrCast(callback)` then
  `v8.pointer_tag.untagPointer(ptr)` and `GlobalHandle{ .ptr = untagged.ptr }`,
  plus `v8_Isolate_GetCurrent()` kept in an `isolate` field; disposed with
  `disposeOptionalGlobalHandle`.
- **Protocol**: `engine.takeCallbackFunction(@ptrCast(callback)) CallbackFunction`
  (TRANSITIONAL until codegen types callback parameters).
- **Ownership**: the binding hands the tagged Global over; the result is
  OWNED - store it, `release()` in deinit. Its `.context` is the incumbent
  realm at the call (the callback context).
- **Pitfalls**: take it exactly once - a second take double-owns the Global.
  Delete the `isolate` field: the realm is `instance.ctx`, and the invoke
  enters the right agent. Do it in the constructor, before anything that can
  fail, and let the `errdefer deinit` release it.

```zig
// before
callback: v8_engine.OptionalGlobalHandle = null,
isolate: ?*v8_engine.ffi.Isolate = null,
const untagged = v8_engine.pointer_tag.untagPointer(@ptrCast(callback));
internal.callback = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };

// after
callback: ?engine.CallbackFunction = null,
internal.callback = engine.takeCallbackFunction(@ptrCast(callback));
// deinit
if (self.callback) |callback| callback.release();
```

### R3. Take a callback-interface argument (a listener, a NodeFilter)

Seen in: EventTarget, node_filter.zig.

- **Intent**: WebIDL callback interface value (object + callback context).
- **V8 pattern**: `runtime.CallbackWrapper` / `v8.CallbackWrapper`,
  `getGlobalValuePtr`, `destroyCallbackWrapper`.
- **Protocol**: `engine.takeCallbackInterface(&wrapper) CallbackInterface`.
- **Ownership**: the wrapper stays its holder's; the CallbackInterface is a
  second, OWNED handle to the object - release it separately.
- **Pitfalls**: listener identity (DOM "event listener whose callback is
  callback") is `engine.sameValue(realm, a.object.value, b.object.value)`, not
  pointer equality of wrappers.

### R4. Invoke a callback function

Seen in: IntersectionObserver, MutationObserver, EventTarget,
WindowOrWorkerGlobalScope, Context, streams_js.

- **Intent**: WebIDL "invoke a callback function" with a callback this value,
  args, and an exception behavior ("report" or "rethrow").
- **V8 pattern**: `v8_Isolate_GetCurrentContext` + `v8_HandleScope_New`,
  `v8_Array_New`/`Set` + `instanceToV8` for the args, `v8_Undefined` or
  `instanceToV8(observer)` for `this`, `v8_Function_Call_Safe` /
  `v8_Function_CallCatching`, `FreeFunctionCallResult`, then
  `v8_Function_GetCreationContext` + `globalForContext` + `reportException`.
- **Protocol**:
  `engine.invokeCallbackFunction(realm, &callback, this_arg, args, behavior) Error!Completion`
  - `this_arg: CallbackThis` = `.undefined` | `.global_this` | `.{ .value = v }`
  - `args: []const JSValue` (BORROWED; `.instance` is wrapped, strings
    converted)
  - `behavior` = `.rethrow` | `.{ .report = .{ .report = fn, .host = ptr } }`
- **Ownership**: `callback` BORROWED (`*const`); args BORROWED; the
  Completion's arm OWNED. With `.report`, what is thrown is reported (R6) and
  the result is `.normal` undefined - still release it.
- **Pitfalls**:
  - "observer as the callback this value" is
    `.{ .value = .{ .instance = observer } }`; the old IntersectionObserver
    passed `v8_Undefined`.
  - Build a `sequence<T>` argument with `createSequenceOfPlatformObjects` /
    `createSequenceOfValues` (R11/R12) and release it after the call.
  - `.rethrow`: the thrown value comes back as `.throw`; to propagate it into
    the calling script, `engine.throwValue(realm, c.throw.value)` then
    `return error.ExceptionPending` (release the Owned after throwing).
  - No HandleScope, no context entering: the operation prepares to run
    script in the callback's realm and to run a callback (incumbent), and
    cleans up.

```zig
// after (MutationObserver notify step 6.4)
const sequence = try engine.createSequenceOfPlatformObjects(realm, records);
defer sequence.release();
const observer: runtime.JSValue = .{ .instance = instance };
const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = observer }, &.{ sequence.value, observer }, .{
    .report = .{ .report = reportException, .host = realm },
});
switch (completion) {
    inline else => |value| value.release(),
}
```

### R5. Call a user object's operation (handleEvent, acceptNode)

Seen in: EventTarget, node_filter.zig.

- **Intent**: WebIDL "call a user object's operation" - a function is called
  itself; an object's `operation` property is got and called with the object
  as `this` (or the given thisArg).
- **V8 pattern**: `CallbackWrapper.callNCatching`, `pushAccessorWindow` /
  `popAccessorWindow`, `wrapInstanceAsV8Object(event)`.
- **Protocol**:
  `engine.callUserObjectOperation(realm, &iface, "handleEvent", .{ .value = current_target }, &.{ .{ .instance = event } }, behavior) Error!Completion`.
- **Ownership**: as R4.
- **Pitfalls**: the accessor-window stack becomes the adapter's incumbent
  tracking - delete push/pop. A throwing `handleEvent` getter is reported
  like a throwing call.

### R6. Report an exception from a callback or script

Seen in: MutationObserver, EventTarget, report_exception, Context.

- **Intent**: HTML "report an exception" for the global of a realm (for a
  callback: its associated realm).
- **V8 pattern**: `v8_Function_GetCreationContext` +
  `report_exception.globalForContext(context)` +
  `report_exception.reportException(global, value, .{})`.
- **Protocol**: pass `ExceptionBehavior.report` with a host `Reporter`. The
  engine calls `report(host, *const ErrorInfo)` after "clean up after running
  script"; `info.realm` is the realm to report for (the callback's associated
  realm), `info.error_value` the thrown value (BORROWED).
- **Ownership**: ErrorInfo and its strings are BORROWED for the call.
- **Pitfalls**: the realm's global is the realm record's
  (`realm.getRealm().?.global_object`), never `getWindowForContext`. The host's
  reporter hands the engine's ErrorInfo to `report_exception.reportErrorInfo`
  (browser/Context.zig's `reportToWindow` is the model):

```zig
/// HTML "report an exception" for the realm the engine names, or `host`'s.
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const fallback: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse fallback;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}
```

  For a value the host holds (a rejected top-level-await promise's reason),
  `engine.extractErrorInformation(realm, value, allocator)` gives the
  ErrorInfo (the caller frees `message` and `filename`);
  script_execution.zig's `reportModuleException` is the model.

### R7. Which realm, and its settings-object state

Seen in: rejected_promises, XMLHttpRequest, WebSocket, Request,
HTMLIFrameElement, streams_js, script_execution, Document.

- **Intent**: ECMAScript current realm; a platform object's relevant realm;
  a realm's global object, document URL, API base URL.
- **V8 pattern**: `v8_Isolate_GetCurrent` + `v8_Isolate_GetCurrentContext` +
  `v8_Context_Dispose` + `context_manager.getWindowForContext(context)`;
  `ctx.getEngineContextAs(v8.ffi.Context)` + `context_manager.getDocumentUrl`;
  `v8_Context_Global` + `GetAlignedPointerFromInternalField(global, 0)`.
- **Protocol**:
  - current realm: `engine.currentRealm() ?Context`;
  - relevant realm: `instance.ctx` (no op);
  - a realm's global object: `realm.getRealm().?.global_object` (host realm
    record; no op);
  - document URL: `realm.documentUrl()` / `realm.setDocumentUrl(url)` (host).
- **Pitfalls**: `currentRealm()` is null outside script - fall back to the
  object's own realm (`orelse instance.ctx`) rather than failing. Never keep
  an isolate or context field "to find the realm later": delete it.

### R8. Run steps inside a realm: a task, or nested

Seen in: rejected_promises, WebSocket, Window, History, Location, Document,
HTMLIFrameElement, script_execution, XMLHttpRequest, Response.

- **Intent**: HTML "queue a global task" (its run side: the task runs in the
  global's realm and ends like a task), or firing an event from engine code
  with the realm current.
- **V8 pattern**: `v8.JsScope.init(realm) orelse return; defer scope.deinit();`,
  or `v8_Isolate_Enter`/`Exit` + `JsScope` + `worker_v8_context.finishTaskIn`.
- **Protocol**:
  - a task (from the host event loop, a timer, a network callback):
    `engine.runTaskInRealm(realm, steps, data) Error!void` - also ends the
    task (a worker's turn end);
  - nested (already inside a task or script, just switching realm):
    `engine.runInRealm(realm, steps, data) Error!void`;
  - scope-shaped code that cannot become a callback:
    `const scope = try engine.prepareToRunScript(realm); defer engine.cleanUpAfterRunningScript(scope);`.
- **Ownership**: `data` BORROWED for the call. `steps: RealmSteps =
  *const fn (data: ?*anyopaque) void` - plain Zig, not `callconv(.c)`.
- **Pitfalls**: a task must not leak what it owns when the realm is gone:
  on an error from runTaskInRealm the steps never ran, so release there.

```zig
// before
const scope = v8.JsScope.init(global.ctx) orelse return disposeAll(task.promises);
defer scope.deinit();
for (task.promises) |p| notifyOne(global, p);

// after
engine.runTaskInRealm(task.global.ctx, notificationSteps, task) catch releaseAll(task.promises);
fn notificationSteps(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data.?));
    for (task.promises) |rejected| notifyOne(task.global, rejected);
}
```

### R9. Queue a microtask

Seen in: IntersectionObserver, MutationObserver, WindowOrWorkerGlobalScope,
streams_js.

- **Intent**: HTML "queue a microtask".
- **V8 pattern**: `v8_Isolate_GetCurrent() orelse { run now }` +
  `v8_Isolate_EnqueueMicrotask(isolate, @ptrCast(&cb), ctx)` with a
  `callconv(.c)` trampoline.
- **Protocol**: `engine.queueMicrotask(agent, steps, data) Error!void` - the
  surrounding agent's queue; a realm's is `realm.agent` (null when no engine
  is behind it).
- **Ownership**: `data` BORROWED until the steps run; a microtask still queued
  at agent teardown is dropped (so allocate `data` so that dropping it leaks
  nothing important, or tie it to the realm).
- **Pitfalls**:
  - The caller names the agent through a realm of it (MutationObserver's
    notify microtask: its caller passes the target's `ctx`, and its
    `agent` is the queue). The steps run with no realm entered.
  - The steps run later: anything they reach may be gone. Hold an Instance as
    (address, slab generation) and check `SlabAllocator.generationOf` first
    (IntersectionObserver's microtask).
  - `error.NotSupported`/`OperationFailed` means no engine behind the realm
    (DOM unit tests): run the steps now only if that is the spec-compatible
    fallback, and say so.
  - The steps report their own exceptions: invoking a callback inside them
    uses `.report` (queueMicrotask once dropped its callback's exception).

```zig
// after
const queued: engine.Error!void = if (realm.agent) |agent| engine.queueMicrotask(agent, mutationMicrotask, ctx) else error.NotSupported;
queued catch |err| {
    allocator.destroy(ctx);
    switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        // No engine behind the realm (unit tests of the DOM alone): notify now.
        else => try mutation_observer_algorithms.notifyMutationObservers(allocator),
    }
};
```

### R10. Perform a microtask checkpoint

Seen in: script_execution, Context, gc_bench, Browser.

- **Protocol**: `engine.performMicrotaskCheckpoint(agent) Error!void` - an
  event loop's, and so an agent's (`realm.agent`).
- **Pitfalls**: HTML "clean up after running script" checkpoints only when
  the JavaScript execution context stack is empty - gate on
  `!engine.hasRunningScript(agent)` or use `cleanUpAfterRunningScript`; an
  unconditional checkpoint is a spec bug. A no-op where
  `microtask_checkpoint_control` is unsupported (JSC).

### R11. `sequence<platform object>` to ES

Seen in: IntersectionObserver, MutationObserver.

- **V8 pattern**: `v8_Array_New(isolate, n)`, a loop of
  `v8_Array_Set(array, context, i, conversions.instanceToV8(isolate, x))`,
  `JSValue.fromHandle(array)`.
- **Protocol**: `engine.createSequenceOfPlatformObjects(realm, instances) Error!Owned`.
- **Ownership**: the Owned array is the caller's (`take()` to return it,
  `release()` after passing it as an argument). Wrapping hands each instance
  to the wrapper cache.
- **Pitfalls**: instances never wrapped because the operation failed are
  still yours - free them on the error path.

```zig
// after (takeRecords)
const array = engine.createSequenceOfPlatformObjects(engine.currentRealm() orelse instance.ctx, records) catch |err| {
    for (records) |record| runtime.Instance.deinit(record);
    return err;
};
return array.take();
```

### R12. `sequence<any>` / `sequence<DOMString>` / `sequence<double>` to ES

Seen in: Element, URLSearchParams, CanvasRenderingContext2D, CookieStore,
CookieStoreManager, streams_js.

- **V8 pattern**: `v8_Array_New` + `v8_String_NewFromUtf8` / `v8_Number_New` +
  `v8_Array_Set` in the current context.
- **Protocol**: `engine.createSequenceOfValues(realm, values: []const JSValue) Error!Owned`
  (`.string` via `JSValue.fromStringRef`, `.number`, dictionaries made by R14).
- **Pitfalls**: it uses CreateDataProperty, so an `Array.prototype` setter is
  never reached (a "known V8 limitation" comment once blamed V8 for what was
  the Set/Define confusion). Better still: codegen converting `sequence<T>`
  return types would remove these hand-built arrays.

### R13. `FrozenArray<T>`

Seen in: IntersectionObserver, CookieChangeEvent,
ExtendableCookieChangeEvent.

- **Protocol**: `engine.createFrozenArray(realm, values: []const JSValue) Error!Owned`.
- **Pitfalls**: a `[SameObject]` / cached FrozenArray attribute keeps its
  Owned (R1) and returns `borrow()`; a per-read one returns `take()`. The old
  IntersectionObserver.thresholds array was never frozen.
  The model for a [SameObject] one is CookieChangeEvent.changed: made on the
  first read in the object's relevant realm (`instance.ctx`), kept in an
  `?engine.Owned` slot, released in the instance deinit (0.8).

```zig
// after
const values = try internal.allocator.alloc(runtime.JSValue, thresholds.len);
defer internal.allocator.free(values);
for (thresholds, values) |t, *v| v.* = runtime.JSValue.fromNumber(t);
return (try engine.createFrozenArray(engine.currentRealm() orelse instance.ctx, values)).take();
```

### R14. An IDL dictionary to an ES object

Seen in: CookieStore, CookieStoreManager, CookieChangeEvent, streams_js.

- **Protocol**: `engine.createDictionaryObject(realm, members: []const DictionaryMember) Error!Owned`,
  `DictionaryMember = { name, value: JSValue }` in the dictionary's member
  order (lexicographic for WebIDL dictionaries; the ReadableStreamReadResult
  `{ value, done }` shape keeps its own).
- **Pitfalls**: a member that is not present is left out, not set to
  undefined.

### R15. "A promise resolved with" / "rejected with"

Seen in: Blob, CookieStore, CookieStoreManager, streams_js, TestUtils.

- **V8 pattern**: `v8_PromiseResolver_New` + `GetPromise` + `Resolve` (the
  resolver frequently never disposed - the Blob leak).
- **Protocol**: `engine.createResolvedPromise(realm, value) Error!Owned`,
  `engine.createRejectedPromise(realm, reason) Error!Owned`; for "rejected
  with a TypeError": `const e = try engine.createSimpleException(realm, .TypeError, msg); defer e.release();`
  then `createRejectedPromise(realm, e.value)`.
- **Ownership**: the promise is OWNED - `take()` it as the operation's result.

### R16. "A new promise", settled later

Seen in: WindowOrWorkerGlobalScope (fetch), streams_js (Deferred),
Response.

- **Protocol**: `var cap = try engine.createPromise(realm);` then
  `try engine.resolvePromise(&cap, value)` / `try engine.rejectPromise(&cap, reason)`,
  and `engine.releasePromiseCapability(&cap)` when done with it.
  `cap.promise` is a BORROWED view: return
  `(try engine.retainValue(realm, cap.promise)).take()`.
- **Pitfalls**: a settle that arrives from a task runs inside
  `runTaskInRealm(realm, ...)` (R8), not with whatever context is current.
  Resolving with a platform object: pass `.{ .instance = x }` - it resolves
  with the wrapper in the promise's realm. Never `rejectPromise` with a Zig
  error: make the exception (R19).

### R17. "React to" a promise

Seen in: repl, script_execution, streams_js.

- **V8 pattern**: `v8_Promise_React`, `v8_Promise_Then` (crashes on a null
  handler), `chainPromiseHandlers` with untyped engine values.
- **Protocol**: `engine.reactToPromise(realm, promise, &steps, data) Error!void`,
  `steps: PromiseReactionSteps = .{ .fulfilled = fn (data, value) void, .rejected = fn (data, reason) void }`;
  either may be null, and the value is BORROWED for the call.
- **Pitfalls**: `data` must live until one of the steps runs (a promise that
  never settles keeps it - and costs 32 bytes of engine handle, measured).
  A non-promise `promise` is a TypeError.

### R18. Mark as handled; [[PromiseIsHandled]]

Seen in: streams_readable, ReadableStream, module_script, rejected_promises.

- **Protocol**: `engine.markPromiseAsHandled(realm, promise: JSValue) void`
  (a non-promise is left alone); `engine.promiseIsHandled(realm, promise) bool`,
  gated on `promise_rejection_tracking` (0.7).
- **Pitfalls**: [[PromiseResult]] has no operation (JSC has none): code that
  needs a rejection's reason keeps it from where it was handed over (R36).

### R19. Create a simple exception / DOMException

Seen in: CookieStore, streams_js, module_script, Response, script_execution.

- **Protocol**: `engine.createSimpleException(realm, kind, message) Error!Owned`
  (`kind: SimpleExceptionKind = EvalError | RangeError | ReferenceError | SyntaxError | TypeError | URIError`),
  `engine.createDOMException(realm, name, message) Error!Owned`.
- **Pitfalls**: to THROW a TypeError from an operation, just return
  `error.TypeError` - make one only when it is a value (a rejection reason,
  a stream's stored error).

### R20. Throw a value

Seen in: streams_js, EventTarget (rethrow).

- **Protocol**: `try engine.throwValue(realm, value); return error.ExceptionPending;`
- **The reverse**, for spec steps that consume an abrupt completion instead
  of propagating it (the Streams size algorithm's result conversion):
  `engine.completionOf(realm, steps, data) Error!?Owned` runs the steps and
  returns what they threw, OWNED, with nothing pending - null on a normal
  completion.

### R21. Convert an ES value to an IDL type (arguments an impl takes unconverted)

Seen in: WebSocket, Blob, URL, HTMLSelectElement, streams_readable,
streams_writable, URLSearchParams, FormData, CanvasRenderingContext2D.

| IDL | Protocol | Result |
|---|---|---|
| DOMString / USVString (an enum's ToString too) | `convertToDOMString` / `convertToUSVString(realm, v, allocator)` | `Error![]u8` OWNED |
| unrestricted double (then clamp/EnforceRange in Zig) | `convertToUnrestrictedDouble(realm, v)` | `Error!f64` (a throwing valueOf is ExceptionPending - `v8_Value_NumberValue` swallowed it) |
| an interface type / a union member | `convertToPlatformObject(realm, v) ?*Instance`, then `stateAs(T)` | null when not a platform object |
| `sequence<Interface>` | `convertToSequenceOfPlatformObjects(realm, v, a)` | `Error![]*Instance` (slice OWNED) |
| `sequence<object>` / `sequence<any>` | `convertToSequenceOfObjects` / `convertToSequence(realm, v, a)` | `Error![]Owned` - release each, free the slice |
| `sequence<DOMString>` or `(DOMString or sequence<DOMString>)` | `convertToSequenceOfDOMStrings(realm, v, a)` | `Error!?[][]u8` - null when not iterable (take the DOMString arm) |
| `sequence<sequence<USVString>>` (URLSearchParams / Headers init) | `convertToSequenceOfStringPairs(realm, v, .usv_string, a)` | `Error!?[]StringRecordEntry`; null when not iterable (take the record arm) |
| `record<K, V>` of strings | `convertToRecordOfStrings(realm, v, keys, values, a)` | `Error![]StringRecordEntry` (`StringRecordEntry.freeAll`) |
| BufferSource | `getCopyOfBufferSourceBytes(realm, v, a)` | `Error!?[]u8`; null when not one; SAB is a TypeError |

- **A union of interface types** (URL.createObjectURL, HTMLSelectElement.add
  are the models): `engine.convertToPlatformObject(realm, v)`, then brand-check
  each member by its state - `object.stateAs(interfaces.X.State) != null` -
  and TypeError when none matches. A `long` arm is ToNumber
  (`convertToUnrestrictedDouble`), then WebIDL's ConvertToInt (NaN and the
  infinities 0, the integer part, modulo 2^32 into the signed range).
- **Pitfalls**: a union is tried arm by arm in WebIDL's order (3.2.24); the
  impl owns the whole union conversion when it takes a raw JSValue
  (docs/lessons/spec-compliance-a-union-argument-reaches-the-impl-in-every-jsvalue-shape.md).
  Better: codegen converting unions of interface types.

### R22. Iterate; iterator records

Seen in: streams_from, CanvasRenderingContext2D, Blob.

- **Protocol**:
  - whole iterable, item by item:
    `engine.iterate(realm, value, each: IterateSteps, data) Error!bool`
    (false when no @@iterator; `each(data, item)` gets the item BORROWED);
  - step by step: `getIterator(realm, v, .sync | .async) Error!*IteratorRecord`,
    `iteratorNext(realm, record) Error!Owned`,
    `iteratorResult(realm, result.value) Error!IteratorResult` (`{ done, value: Owned }`),
    `iteratorReturn(realm, record, value) Error!?Owned`,
    `releaseIteratorRecord(record)`.
- **Pitfalls**: `.async` over a sync iterable is CreateAsyncFromSyncIterator
  (done in the adapter). Release every `iteratorNext` result and every
  `IteratorResult.value`. `getIterator` of a primitive reads its method
  through ToObject, as ECMAScript's GetV does - a string iterates its code
  points; undefined and null are TypeErrors. `iterate` and the sequence
  conversions are WebIDL's, and reject a non-object (3.2.28).

### R23. Get / Set / HasProperty / DefinePropertyOrThrow

Seen in: streams_js, Element, HTMLIFrameElement, repl, Context.

- **Protocol**: `getProperty(realm, object, name) Error!Owned`,
  `setProperty(realm, object, name, value) Error!void` (Set with Throw true;
  V8's embedder Set is sloppy, a declared deviation),
  `hasProperty(realm, object, name) Error!bool`,
  `defineOwnProperty(realm, object, name, value, .{ .writable, .enumerable, .configurable }) Error!void`.
  `object` may be an `.instance` (the global: `.{ .instance = window }`).
- **Helpers** (plain `pub fn`s in the facade, built on the ops):
  `getPropertyBoolean(realm, object, name) Error!?bool` - a boolean
  dictionary member (null when not present, else ToBoolean);
  `getPropertyPlatformObject(realm, object, name) Error!?*Instance` - an
  interface-typed member (null when not present, TypeError when not one).
- **Pitfalls**: a non-object is a TypeError; a throwing getter is
  ExceptionPending.

### R24. Type(V), IsCallable, SameValue

Seen in: EventTarget, rejected_promises, streams_js, repl.

- **Protocol**: `typeOf(realm, v) ValueType`, `isCallable(realm, v) bool`,
  `sameValue(realm, a, b) bool` (SameValue: for objects, identity - the same
  answer as IsStrictlyEqual; they differ only for NaN and ±0),
  `toBoolean(realm, v) bool` (ECMAScript ToBoolean; runs no script;
  `document.all` is false).

### R25. ArrayBuffers and views

Seen in: Blob, WebSocket, streams_js.

- **Protocol**: `createArrayBuffer(realm, bytes)` (copy),
  `allocateArrayBuffer(realm, len)` (zeroed),
  `createArrayBufferView(realm, view_type, buffer, byte_offset, length)`,
  `describeArrayBufferView(realm, v) ?ArrayBufferViewDescription`,
  `writeIntoArrayBufferView(realm, view, bytes, offset)`,
  `borrowArrayBufferBytes(realm, buffer) ?[]u8` (BORROWED until script next
  runs or the buffer detaches), `isDetachedBuffer`, `canTransferArrayBuffer`,
  `transferArrayBuffer(realm, buffer) Error!Owned`,
  `getViewedArrayBuffer(realm, view) Error!Owned`.
- **Pitfalls**: bounds are the caller's to check (no RangeError from the
  engine), as Streams does.

### R26. Structured serialization

Seen in: WindowOrWorkerGlobalScope, Window, History.

- **Protocol**: `structuredSerializeForStorage(realm, v, a) Error![]u8`,
  `structuredDeserialize(realm, bytes) Error!Owned`,
  `structuredSerializeWithTransfer(realm, v, transfer_list, check, check_data, a) Error!SerializedWithTransfer`,
  `structuredDeserializeWithTransfer(realm, bytes, array_buffers) Error!Owned`.
- **Pitfalls**: `DataCloneError` means "throw a DataCloneError" (nothing
  thrown yet); the deserialized value is OWNED (History keeps it: R1).

### R27. Wrapper lifetime (engine concerns, no spec)

Seen in: same_object, script_execution, Document, Context, Window,
WebSocket, XMLHttpRequest, Node.

| Need | Protocol |
|---|---|
| Keep a [SameObject] child's wrapper for its owner's life (Blink traces it) | `same_object.Pin.hold(child)` = `engine.retainValue(child.ctx, .{ .instance = child })`, released in the owner's deinit |
| Pending activity (a running Worker, an open socket, an armed timer, an IntersectionObserver with targets) | `engine.keepPlatformObjectAlive(instance)` / `engine.releasePlatformObject(instance)` - a flag, not a count: keep while the condition holds, release when it ends (IntersectionObserver.holdWhileObserving is the model) |
| "Has script seen this object?" (free an unheard event) | `engine.hasWrapper(instance)` (`Instance.releaseIfUnwrapped` uses it) |
| The host freed an object its wrapper would free again | `engine.platformObjectDestroyed(instance)` |

- **Pitfalls**: `retainValue` of an `.instance` wraps in the realm you pass -
  always the instance's own `ctx`.

### R27b. An Event subclass's constructor

Seen in: CookieChangeEvent (and, as follow-ups, ErrorEvent, CustomEvent,
PromiseRejectionEvent, MouseEvent, which write `state.base.own` directly).

- **Protocol**: none - `EventImpl.innerEventCreationSteps(instance, type,
  dictionary.base)` (DOM "inner event creation steps" plus the constructor's
  type step, through the ancestor's impl), then the interface's own event
  constructing steps (its own members). The instance deinit calls
  `EventImpl.deinit(instance)` after its own.
- **Pitfalls**: without the initialized flag `dispatchEvent` throws
  InvalidStateError; an interface on the binding's skip list is not
  reachable from script at all (interface_bindings `interface_skip_list`).

### R28. A platform object's wrapper lives in its relevant realm

Seen in: Document, HTMLIFrameElement.

- **Protocol**: none - an `.instance` converts to its wrapper in its relevant
  realm. Delete `setBoundV8Wrapper` / pre-wrapping code; the adapter owns
  wrapper identity.

### R29. Return a platform object (or a nullable one) from a getter

Seen in: IntersectionObserver, streams_js.

- **V8 pattern**: `conversions.instanceToV8(isolate, x)` +
  `JSValue.fromHandle(...)` - which also returned a borrowed wrapper-cache
  Global as OWNED.
- **Protocol**: none - `return runtime.JSValue.fromInstance(x);` (or the
  typed `*runtime.Instance` return the generated signature asks for); the
  binding wraps it.

### R30. Evaluate a host script for its completion value

Seen in: Context, repl, wpt_browser, lib_exports, webdriver,
HTMLIFrameElement, browser_document_test.

- **Protocol**: `evaluateClassicScript(realm, .{ .utf8 = src }, url, host_defined, reporter) Error!Owned`,
  `evaluateClassicScriptToString(realm, source, url, host_defined, allocator, reporter) Error![]u8`.
  HTML "evaluate a javascript: URL" uses the first and tests `.string`.
- **Pitfalls**: release the completion (lib_exports and WebDriver leaked
  one per call). A throw is reported AND the call fails.

### R31. Run a classic script

Seen in: script_execution, Context, gc_bench.

- **Protocol**: `runClassicScript(realm, source: ScriptSource, url, host_defined, reporter) Error!void`;
  `ScriptSource = .{ .utf8 = bytes } | .{ .string = value }` (a timer's string
  handler keeps every code unit). Muting is the reporter's.
- **Pitfalls**: `host_defined` is the classic script an `import()` in it
  names as its referrer (`ImportReferrer.script`): pass a
  `module_script.ClassicScript` (its base URL) that lives as long as the
  realm, since a function the script defined can call import() at any time;
  or null, and import() resolves against the document's base URL.

### R32. Compile an event handler content attribute

Seen in: Element.

- **Protocol**: `compileEventHandler(realm, &EventHandlerSource{ body, name, url, lineno, parameters, document, form_owner, element }, reporter) Error!?Owned`
  (null after reporting the SyntaxError).

### R33. ES module scripts **[module_scripts]**

Seen in: module_script, script_execution.

- **Protocol**: `parseModule` / `parseJSONModule(realm, source, url, host_defined) Error!ParseResult`,
  `moduleRequests(record, a)`, `linkModule(realm, record, resolve, data) Error!?Owned`,
  `evaluateModule(realm, record) Error!ModuleEvaluation` (`completed` |
  `rejected: Owned` | `pending: Owned`), `finishDynamicImport(request, outcome)`,
  `releaseModuleRecord(record)`; hooks `loadImportedModule`, `importMetaUrl`.
  [[HostDefined]] (`host_defined`) is the host's module script: Link's
  resolve and the hooks find it through the record, never by V8 identity
  hash. html/module_script.zig and script_execution.zig's `module_hooks` are
  the model; everything that touches a record sits behind
  `engine.capabilities.module_scripts != .unsupported`.

### R34. Realms: create, destroy, entry, incumbent, function realm

Seen in: Context, HTMLIFrameElement, Window, Location.

- **Protocol**: `createWindowRealm(&WindowRealmOptions) Error!Context`,
  `destroyWindowRealm(realm)`, `entryRealm() ?Context`,
  `incumbentRealm() ?Context`, `functionRealm(value) ?Context`
  [`exact_function_realm`; fallback: `CallbackFunction.context`].
- **Pitfalls**: `GetEnteredOrMicrotaskContext` is not the entry realm, and the
  accessor-window stack is not the incumbent - both become the adapter's
  stacks.

### R35. Agents and the process-wide engine

Seen in: Browser, lib_exports, TestUtils.

- **Protocol**: `initializeEngine(.{ .snapshot })` / `deinitializeEngine()`,
  `createAgent(.{ .can_block, .from_snapshot, .hooks, .host })` /
  `destroyAgent(agent)`, `requestGarbageCollection(agent)` (testing only).
  `hooks` is the whole agent's HostHooks: a Window agent's combines
  `rejected_promises.hooks` and `script_execution.module_hooks`.

### R36. Host hooks (promise rejection tracking)

Seen in: rejected_promises.

- **Intent**: HostPromiseRejectionTracker and HTML checkpoint step 5.
- **V8 pattern**: `v8_Isolate_SetPromiseRejectCallback` +
  `v8_Isolate_AddMicrotasksCompletedCallback`, callbacks taking raw Globals,
  `v8_Promise_Result`, `v8_Value_StrictEquals`, `v8_Promise_HasHandler`.
- **Protocol**: the host exports `pub const hooks: engine.HostHooks`
  (`promiseRejectionTracker(host, realm, promise: Owned, operation, reason: ?Owned)`,
  `afterMicrotaskCheckpoint(host, agent)`); `createAgent` installs them.
  Inside: `sameValue` for promise identity, `promiseIsHandled` (gated),
  PromiseRejectionEvent's reason from the kept `reason` (no [[PromiseResult]]
  operation).
- **Pitfalls**: until Browser creates its agent with `createAgent`, a V8
  install shim stays in the host file as its only V8 references, marked
  `TODO(protocol)`, forwarding V8's own callbacks into the same host code
  (rejected_promises.zig and script_execution.zig's module section are the
  models).

### R37. Asynchronous iterator objects

Seen in: streams_readable.

- **Protocol**: `createAsyncIterator(realm, &AsyncIteratorSteps{ .next, .@"return", .finalize }, data) Error!Owned`.
  `next(data)` returns a promise (or value) for `{ value, done }` - OWNED;
  `finalize(data)` runs during GC and must not touch the engine.
- **Pitfalls**: the engine keeps the ongoing promise and "is finished"; the
  steps must not re-implement WebIDL 3.7.10's queueing.

### R38. Diagnostics (tools only)

Seen in: gc_bench, wpt_runner, snapshot tools.

- **Protocol**: `heapStatistics(agent)`, `writeHeapSnapshot(agent, path)`,
  `diagnosticCounters(allocator)` - each capability-gated; print what the
  adapter reports, never V8 family names. Snapshot generation is
  adapter-internal: it moves under src/runtime/engines/v8/.

### R39. Delete and rename

- Delete what nothing calls (with an untruncated grep over src/, tests/,
  tools/, build.zig, docs/), in the commit that migrates its file:
  src/dom/event_target.zig, FormData's dispatchAppend/dispatchSet,
  MutationObserver.getCallback and src/webidl/conversions_test.zig went this
  way.
- Rename V8-named fields and aliases that hold no engine call (`v8_ctx` ->
  `realm`, `isolate` -> gone, `.v8_serialized` -> `.engine_serialized`).
- A dead legacy path that cannot name a realm says so in a comment and takes
  the no-realm fallback (mutation_observer_algorithms' `*Node` path).

---

## 3. Known gaps (report, don't work around)

1. **No [[PromiseResult]]** (by design: JavaScriptCore has none): a reason the
   host needs is kept from where the engine handed it over (R36's `reason`).
2. **A dictionary `any` member that is JS `null` arrives as absent** (Zig
   `null`), so `new ErrorEvent("x", {error: null}).error` is undefined. The
   dictionary conversion (conversions.zig) must give a present `any` member
   `.null`.
3. **The binding layer's getters** still wrap an `.instance` through
   `conversions.instanceToV8`, in the current context: the relevant-realm
   rule holds for every protocol operation, not yet for a getter's return
   value. Until it does, a cross-realm getter can make a second wrapper.
