//! A dedicated worker's agent and realm, as V8 makes them: the engine half of
//! HTML "run a worker" (10.2.4), behind the Engine table (AGENTS.md, "The
//! engine boundary").
//!
//! The HTML half - the WorkerGlobalScope's settings, the worker's event loop
//! and its tasks, its ports, its lifecycle, closing and terminating - lives in
//! src/html (the worker host) and reaches the engine only through the Engine
//! table. What is here is what only the engine can do:
//!
//! - an agent: a V8 isolate of the worker's own (createAgent, destroyAgent);
//! - a realm in it whose global object is a DedicatedWorkerGlobalScope
//!   platform object (createWorkerRealm), and the realm's end
//!   (destroyWorkerRealm);
//! - the engine's own work for the agent - V8's posted platform tasks, such as
//!   an asynchronous WebAssembly compile settling its promise
//!   (hasPendingEngineWork, runEngineTasks);
//! - built-in functions a host installs on a global (defineBuiltinFunction),
//!   and IsCallable (isCallable).
//!
//! An agent is an isolate: `runtime.Agent` is `v8::Isolate` here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const EngineError = runtime.EngineError;

const ffi = @import("ffi.zig");
const engine = @import("engine.zig");
const conversions = @import("conversions.zig");
const value_operations = @import("value_operations.zig");
const context_manager = @import("context_manager.zig");
const template_registry = @import("template_registry.zig");
const interface_bindings = @import("interface_bindings.zig");
const V8Interface = @import("interface.zig").V8Interface;
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
const helpers = @import("helpers.zig");
const isolate_templates = @import("isolate_templates.zig");
const isolate_allocator = @import("isolate_allocator.zig");
const event_loop = @import("event_loop.zig");
const wrapper_cache = @import("wrapper_cache.zig");

fn isolateOf(agent: *runtime.Agent) *ffi.Isolate {
    return @ptrCast(@alignCast(agent));
}

// ============================================================================
// Agents
// ============================================================================

/// Engine table `createAgent`: a new isolate. OWNED: `destroyAgent`.
pub fn createAgent() EngineError!*runtime.Agent {
    // The main browser context has normally initialized the platform already
    // (with the runtime flag set); this is a no-op then.
    ffi.v8_Platform_Initialize();
    const isolate = ffi.v8_Isolate_New() orelse return EngineError.OperationFailed;
    return @ptrCast(isolate);
}

/// Engine table `destroyAgent`: dispose the isolate. Every realm in it has
/// been destroyed, and nothing the process keeps holds one of its handles.
pub fn destroyAgent(agent: *runtime.Agent) void {
    ffi.v8_Isolate_Dispose(isolateOf(agent));
}

/// Engine table `hasRunningScript`: whether `agent`'s execution context stack
/// may be non-empty here - V8's answer is whether its isolate is the one
/// entered on this thread.
pub fn hasRunningScript(agent: *runtime.Agent) bool {
    return ffi.v8_Isolate_GetCurrent() == isolateOf(agent);
}

/// `agent` entered for the scope of a call, if it was not the current one.
const EnteredAgent = struct {
    isolate: *ffi.Isolate,
    entered: bool,

    fn enter(agent: *runtime.Agent) EnteredAgent {
        const isolate = isolateOf(agent);
        const entered = ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) ffi.v8_Isolate_Enter(isolate);
        return .{ .isolate = isolate, .entered = entered };
    }

    fn leave(self: EnteredAgent) void {
        if (self.entered) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// Engine table `hasPendingEngineWork`: whether V8 has background work for
/// `agent` that will post a task when it is done (an asynchronous compile) -
/// a host keeps pumping (`runEngineTasks`) while it does, as d8's message
/// loop waits on the same test (Shell::CompleteMessageLoop).
pub fn hasPendingEngineWork(agent: *runtime.Agent) bool {
    const entered = EnteredAgent.enter(agent);
    defer entered.leave();
    return ffi.v8_Isolate_HasPendingBackgroundTasks(entered.isolate);
}

/// Engine table `runEngineTasks`: run the tasks V8 has posted to the platform
/// for `agent`; whether any ran.
pub fn runEngineTasks(agent: *runtime.Agent) bool {
    const entered = EnteredAgent.enter(agent);
    defer entered.leave();
    return event_loop.pumpPlatformTasks(entered.isolate);
}

// ============================================================================
// Worker realms
// ============================================================================

/// A realm this file made: what its end needs after the context manager has
/// retired it (and `engine_ctx` reads null).
const Record = struct {
    realm: runtime.Context,
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    allocator: std.mem.Allocator,
};

/// Every worker realm made on this thread and not yet destroyed.
threadlocal var records: std.ArrayListUnmanaged(Record) = .empty;

fn take(realm: runtime.Context) ?Record {
    for (records.items, 0..) |record, i| {
        if (record.realm == realm) return records.swapRemove(i);
    }
    return null;
}

/// The DedicatedWorkerGlobalScope interface template in `isolate`, which must
/// be entered. Templates belong to one isolate, and the registry is where
/// every later lookup - the interface object installForScope puts on the
/// global, a subclass's Inherit() - finds this one, so the global object and
/// `DedicatedWorkerGlobalScope.prototype` share a template.
fn globalScopeTemplate(isolate: *ffi.Isolate) *ffi.FunctionTemplate {
    const name = interfaces.DedicatedWorkerGlobalScope.Meta.name;
    if (template_registry.getTemplateForIsolate(name, isolate)) |template| return template;
    const template = V8Interface(interfaces.DedicatedWorkerGlobalScope).createTemplate(isolate);
    template_registry.register(name, template, isolate);
    return template;
}

/// Engine table `createWorkerRealm`: HTML "run a worker" step 6 - a new realm
/// in `agent` whose global object is a new DedicatedWorkerGlobalScope - with
/// every interface [Exposed] to a dedicated worker installed on it. OWNED:
/// `destroyWorkerRealm`.
pub fn createWorkerRealm(agent: *runtime.Agent, options: runtime.WorkerRealmOptions) EngineError!runtime.WorkerRealm {
    const isolate = isolateOf(agent);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    // Any API call that creates a Local needs a HandleScope.
    const handle_scope = ffi.v8_HandleScope_New(isolate) orelse return EngineError.OperationFailed;
    defer ffi.v8_HandleScope_Dispose(handle_scope);

    // The realm's global object is a DedicatedWorkerGlobalScope: the context
    // is created from that interface's template, which makes the global
    // object one of its platform objects, with its internal fields - Blink's
    // WorkerOrWorkletScriptController::Initialize does the same with the
    // interface template's InstanceTemplate().
    const context = ffi.v8_Context_NewWithGlobalConstructor(isolate, globalScopeTemplate(isolate)) orelse
        return EngineError.OperationFailed;
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);

    // `self` as a data property equal to the global object, as the window
    // does: testharness.js runs `(function(global_scope){...})(self)` and
    // needs `self === globalThis`.
    defineSelf(isolate, context);
    registerWorkerInterfaces(isolate, context);

    // The realm's runtime context: the context manager's entry for it. Every
    // Instance created in the realm points here - the global scope first.
    const realm = context_manager.getOrCreateWithExternalEventLoop(context, options.timer, null, options.allocator) catch {
        ffi.v8_Context_Dispose(context);
        return EngineError.OperationFailed;
    };
    records.append(std.heap.page_allocator, .{
        .realm = realm,
        .isolate = isolate,
        .context = context,
        .allocator = options.allocator,
    }) catch {
        context_manager.removeContext(context);
        ffi.v8_Context_Dispose(context);
        return EngineError.OutOfMemory;
    };
    // Tasks the engine runs into this realm from outside it end the host's way.
    realm.end_of_task = options.end_of_task;
    // The worker's script URL is the realm's API base URL.
    realm.setDocumentUrl(options.url) catch {};
    // The host records the realm's settings before its global object exists:
    // the global scope reads them as it is made.
    if (options.on_realm) |hook| hook(options.data, realm);

    // Every interface exposed in a DedicatedWorker scope, per WebIDL's
    // [Exposed].
    interface_bindings.installForScope(isolate, context, .DedicatedWorker);

    // The platform object behind the global, its prototype chain and its own
    // members - after the interface objects, whose prototypes it links.
    const global_scope = bindGlobalScope(isolate, context, realm) catch |err| {
        destroyWorkerRealmIn(isolate, context, realm, options.allocator, null, null);
        return err;
    };
    return .{ .realm = realm, .global_scope = global_scope };
}

fn defineSelf(isolate: *ffi.Isolate, context: *ffi.Context) void {
    const global = ffi.v8_Context_Global(context) orelse return;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate, "self", 4) orelse return;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(global));
}

/// The interfaces a worker realm had before installForScope ran over it (the
/// same set it always registered first). installForScope then installs every
/// interface exposed to a dedicated worker.
fn registerWorkerInterfaces(isolate: *ffi.Isolate, context: *ffi.Context) void {
    V8Interface(interfaces.URL).registerGlobal(isolate, context, "URL");
    V8Interface(interfaces.URLSearchParams).registerGlobal(isolate, context, "URLSearchParams");
    V8Interface(interfaces.Event).registerGlobal(isolate, context, "Event");
    V8Interface(interfaces.EventTarget).registerGlobal(isolate, context, "EventTarget");
    V8Interface(interfaces.DOMException).registerGlobal(isolate, context, "DOMException");
    V8Interface(interfaces.WebSocket).registerGlobal(isolate, context, "WebSocket");
    V8Interface(interfaces.CloseEvent).registerGlobal(isolate, context, "CloseEvent");
    V8Interface(interfaces.MessageEvent).registerGlobal(isolate, context, "MessageEvent");
    V8Interface(interfaces.MessagePort).registerGlobal(isolate, context, "MessagePort");
    V8Interface(interfaces.MessageChannel).registerGlobal(isolate, context, "MessageChannel");
    V8Interface(interfaces.Worker).registerGlobal(isolate, context, "Worker");
    V8Interface(interfaces.Blob).registerGlobal(isolate, context, "Blob");
}

/// The other half of "run a worker" step 6: the platform object behind the
/// global object, and what V8 does not set up for a global made from an
/// interface template.
///
/// - The DedicatedWorkerGlobalScope Instance, created through its interface
///   in the realm's own runtime context, goes in internal field 0 of the
///   global proxy - which the bindings read for every [Global] member and
///   every receiver check - and of the global object behind it (Blink's
///   SetNativeInfoForGlobal does both).
/// - The realm's wrapper cache maps it to the global proxy, so handing the
///   scope to script (`self`, an event's currentTarget) returns the global
///   itself - as createWindowBoundToGlobal does for a Window.
/// - The prototype chain: global -> DedicatedWorkerGlobalScope.prototype ->
///   WorkerGlobalScope.prototype -> EventTarget.prototype.
/// - DedicatedWorkerGlobalScope's own members as own properties of the
///   global: WebIDL puts a [Global] interface's members on the object.
fn bindGlobalScope(isolate: *ffi.Isolate, context: *ffi.Context, realm: runtime.Context) EngineError!*runtime.Instance {
    const instance = interfaces.DedicatedWorkerGlobalScope.init(realm.allocator, realm) catch
        return EngineError.OperationFailed;
    bindGlobalFields(context, instance);

    // The cache takes this Global.
    const global = ffi.v8_Context_Global(context) orelse return EngineError.OperationFailed;
    const cache_storage = realm.getV8WrapperCacheStorage() orelse {
        ffi.v8_Object_Dispose(global);
        return EngineError.OperationFailed;
    };
    const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));
    cache.set(instance, global, isolate) catch return EngineError.OutOfMemory;

    const global_obj = ffi.v8_Context_Global(context) orelse return EngineError.OperationFailed;
    defer ffi.v8_Object_Dispose(global_obj);
    linkGlobalPrototype(isolate, context, global_obj);

    const Binding = V8Interface(interfaces.DedicatedWorkerGlobalScope);
    Binding.registerPropertiesAsOwnOnObject(isolate, context, global_obj);
    Binding.registerMethodsAsOwnOnObject(isolate, context, global_obj);
    return instance;
}

/// Point internal field 0 of the global proxy, and of the global object
/// behind it, at `instance` - or at nothing, before the instance is freed.
fn bindGlobalFields(context: *ffi.Context, instance: ?*runtime.Instance) void {
    const global = ffi.v8_Context_Global(context) orelse return;
    defer ffi.v8_Object_Dispose(global);
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(instance));
    // The V1 GetPrototype on a global proxy is V8's from_javascript=false
    // path: it returns the hidden JSGlobalObject, not what script sees.
    const inner_val = ffi.v8_Object_GetPrototype(global) orelse return;
    defer ffi.v8_Value_Dispose(inner_val);
    const inner = helpers.asObject(inner_val) orelse return;
    ffi.v8_Object_SetAlignedPointerInInternalField(inner, 0, @ptrCast(instance));
}

/// Make DedicatedWorkerGlobalScope.prototype the global object's prototype,
/// as script sees it.
///
/// A [Global] object has an immutable prototype (WebIDL), so the global
/// object's [[Prototype]] is fixed when the context is created - and V8 fixes
/// it to a placeholder: for a global made from a template, it builds the
/// global object's constructor function itself, and that function's prototype
/// is a fresh object on Object.prototype, holding only `constructor`. The
/// placeholder is an ordinary object, so it is what gets linked, exactly as
/// window_properties.zig does for a Window:
///   global -> placeholder -> DedicatedWorkerGlobalScope.prototype -> ...
/// Its `constructor` goes, so `self.constructor` is the interface object.
/// Only the V2 prototype calls: the V1 ones reach the hidden global object.
fn linkGlobalPrototype(isolate: *ffi.Isolate, context: *ffi.Context, global: *ffi.Object) void {
    const name = interfaces.DedicatedWorkerGlobalScope.Meta.name;
    const name_key = ffi.v8_String_NewFromUtf8(isolate, name.ptr, name.len) orelse return;
    defer ffi.v8_String_Dispose(name_key);
    const interface_val = ffi.v8_Object_Get(global, context, @ptrCast(name_key)) orelse return;
    defer ffi.v8_Value_Dispose(interface_val);
    const interface_obj = helpers.asObject(interface_val) orelse return;
    const proto_key = ffi.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return;
    defer ffi.v8_String_Dispose(proto_key);
    const proto = ffi.v8_Object_Get(interface_obj, context, @ptrCast(proto_key)) orelse return;
    defer ffi.v8_Value_Dispose(proto);

    if (ffi.v8_Object_SetPrototypeV2(global, context, proto)) return;
    const placeholder_val = ffi.v8_Object_GetPrototypeV2(global) orelse return;
    defer ffi.v8_Value_Dispose(placeholder_val);
    if (ffi.v8_Value_StrictEquals(placeholder_val, proto)) return;
    const placeholder = helpers.asObject(placeholder_val) orelse return;
    if (!ffi.v8_Object_SetPrototypeV2(placeholder, context, proto)) return;
    const ctor_key = ffi.v8_String_NewFromUtf8(isolate, "constructor", 11) orelse return;
    defer ffi.v8_String_Dispose(ctor_key);
    _ = ffi.v8_Object_Delete(placeholder, context, @ptrCast(ctor_key));
}

/// Engine table `destroyWorkerRealm`: the realm's end - what Blink's
/// WorkerOrWorkletScriptController::DisposeContextIfNeeded does: clear the
/// global's native info, then release the per-context data (the callbacks
/// its script registered, its wrapper cache and every Instance in it - the
/// global scope first). `retire(data)` runs once nothing can run in the realm
/// any more but its agent's handles are still live, with the agent entered -
/// for what a host releases with the realm (its fetches in flight). Then
/// what the process keeps per isolate for the realm goes. The agent stays:
/// `destroyAgent`.
pub fn destroyWorkerRealm(realm: runtime.Context, retire: ?runtime.RealmSteps, data: ?*anyopaque) void {
    const record = take(realm) orelse return;
    destroyWorkerRealmIn(record.isolate, record.context, realm, record.allocator, retire, data);
}

fn destroyWorkerRealmIn(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    retire: ?runtime.RealmSteps,
    data: ?*anyopaque,
) void {
    _ = realm;
    {
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        const handle_scope = ffi.v8_HandleScope_New(isolate);
        defer if (handle_scope) |scope| ffi.v8_HandleScope_Dispose(scope);
        ffi.v8_Context_Enter(context);
        defer ffi.v8_Context_Exit(context);

        // The global scope is freed with the realm's wrapper cache just
        // below; the global object must not point at it after.
        bindGlobalFields(context, null);

        // The entry is retired, so `engine_ctx` reads null from here on:
        // that is how anything holding the realm across turns learns it has
        // gone.
        context_manager.removeContext(context);
        if (retire) |steps| steps(data);

        // v8_wrapper.cpp caches ONE isolate's async iterator template at a
        // time, and resets the cached one whenever another isolate asks. Left
        // holding this isolate's, the page's next `for await` over a stream
        // reset a handle of the disposed isolate: V8_Fatal in
        // GlobalHandles::NodeSpace::Release. Cleared now, while this isolate
        // lives - and only if it is this isolate's.
        ffi.v8_ClearAsyncIteratorTemplateCacheFor(isolate);
    }
    ffi.v8_Context_Dispose(context);

    // What the process keeps per isolate: its templates in the registry
    // (disposed here - Globals of this isolate), its template storage and its
    // allocator in the isolate's data slots.
    template_registry.clearForIsolate(isolate);
    isolate_templates.cleanupTemplateStorage(isolate, allocator);
    isolate_allocator.deinitIsolateAllocator(isolate);
}

// ============================================================================
// Built-in functions and callback functions
// ============================================================================

/// Engine table `defineBuiltinFunction`: ECMAScript CreateBuiltinFunction for
/// `function`, defined as the own data property `name` of `realm`'s global
/// object. `function` is BORROWED for the realm's life: the built-in reads it
/// on every call.
pub fn defineBuiltinFunction(realm: runtime.Context, name: []const u8, length: u32, function: *const runtime.BuiltinFunction) EngineError!void {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;

    const external = ffi.v8_External_New(isolate, @ptrCast(@constCast(function))) orelse return EngineError.OperationFailed;
    const template = ffi.v8_FunctionTemplate_New(isolate, builtinCallback, @ptrCast(external)) orelse return EngineError.OperationFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    ffi.v8_FunctionTemplate_SetLength(template, @intCast(length));
    const created = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return EngineError.OperationFailed;
    defer ffi.v8_Function_Dispose(created);
    const key = ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return EngineError.OperationFailed;
    defer ffi.v8_String_Dispose(key);
    const global = ffi.v8_Context_Global(context) orelse return EngineError.OperationFailed;
    defer ffi.v8_Object_Dispose(global);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(created))) return EngineError.OperationFailed;
}

/// A script argument as the built-in's steps see it: a primitive as itself, a
/// string as its UTF-8 (owned here), anything else a borrowed handle.
fn argumentValue(isolate: *ffi.Isolate, context: *ffi.Context, value: *ffi.Value, allocator: std.mem.Allocator) !runtime.JSValue {
    if (ffi.v8_Value_IsUndefined(value)) return runtime.JSValue.jsUndefined;
    if (ffi.v8_Value_IsNull(value)) return runtime.JSValue.jsNull;
    if (ffi.v8_Value_IsBoolean(value)) return .{ .boolean = ffi.v8_Value_BooleanValue(value, isolate) };
    if (ffi.v8_Value_IsNumber(value)) return .{ .number = ffi.v8_Value_NumberValue(value, context) };
    if (ffi.v8_Value_IsString(value)) {
        const str: *ffi.String = @ptrCast(value);
        const len = ffi.v8_String_Utf8Length(str);
        if (len <= 0) return runtime.JSValue.fromStringRef("");
        const buffer = try allocator.alloc(u8, @intCast(len));
        _ = ffi.v8_String_WriteUtf8(str, buffer.ptr, len);
        return runtime.JSValue.fromStringOwned(buffer);
    }
    return .{ .handle = .{ .ptr = @ptrCast(value), .needs_disposal = false, .handle_scope = .global } };
}

fn builtinCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const data = info.getData();
    defer ffi.v8_Global_Dispose(data);
    const function: *const runtime.BuiltinFunction = @ptrCast(@alignCast(ffi.v8_External_Value(@ptrCast(data)) orelse return));
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(context);

    const allocator = std.heap.page_allocator;
    const argc: usize = @intCast(@max(info.length(), 0));
    var handles_buf: [8]*ffi.Value = undefined;
    var values_buf: [8]runtime.JSValue = undefined;
    const handles = if (argc <= handles_buf.len) handles_buf[0..argc] else allocator.alloc(*ffi.Value, argc) catch return;
    defer if (argc > handles_buf.len) allocator.free(handles);
    const values = if (argc <= values_buf.len) values_buf[0..argc] else allocator.alloc(runtime.JSValue, argc) catch return;
    defer if (argc > values_buf.len) allocator.free(values);
    var made: usize = 0;
    defer for (handles[0..made], values[0..made]) |handle, *value| {
        value.deinit(allocator);
        ffi.v8_Global_Dispose(handle);
    };
    while (made < argc) : (made += 1) {
        // Owned Global for each argument; its value borrows it.
        handles[made] = info.get(@intCast(made));
        values[made] = argumentValue(isolate, context, handles[made], allocator) catch {
            ffi.v8_Global_Dispose(handles[made]);
            return;
        };
    }

    const result = function.steps(function.data, values) catch |err| switch (err) {
        // Already thrown: leave it in flight.
        error.ExceptionPending => return,
        else => {
            conversions.throwWebIDLErrorFromContext(isolate, context, @errorName(err));
            return;
        },
    };
    const returned = conversions.toV8Value(runtime.JSValue, isolate, context, result) catch return;
    info.setReturnValue(returned);
    // A value made for the return, or a handle the steps handed over, is
    // released now that V8 holds its own reference.
    switch (result) {
        .handle => |h| if (h.needs_disposal) ffi.v8_Global_Dispose(returned),
        .instance => {},
        else => ffi.v8_Global_Dispose(returned),
    }
}

/// Engine table `isCallable`: ECMAScript IsCallable(`value`).
pub fn isCallable(value: runtime.JSValue) bool {
    // A `.handle` is a Global either way it is tagged (value_operations.handleOf).
    const handle = value_operations.handleOf(value) orelse return false;
    return ffi.v8_Value_IsFunction(handle);
}

/// Engine table `keepPlatformObjectAlive`: the wrapper cache holds
/// `instance`'s wrapper strongly from now on, until the realm's cache goes.
pub fn keepPlatformObjectAlive(instance: *runtime.Instance) void {
    wrapper_cache.holdStrong(instance);
}
