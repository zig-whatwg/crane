//! A worklet's realm, as V8 makes it: the engine half of HTML 11.3.1.2
//! "create a worklet global scope" (step 3) and "terminate a worklet global
//! scope" (step 5), behind the engine protocol (AGENTS.md, "The engine
//! boundary").
//!
//! The HTML half - the worklet's global scopes, its added modules, fetching
//! and running its module scripts, terminating its global scopes with their
//! document - lives in src/html/worklets. What is here is what only the
//! engine can do: a context whose global object is a PaintWorkletGlobalScope,
//! LayoutWorkletGlobalScope, AnimationWorkletGlobalScope or
//! AudioWorkletGlobalScope platform object, with what is [Exposed] to that
//! worklet installed on it, and that context's end.
//!
//! Where it runs: in the agent of the worklet's outside settings - the
//! owner Window's isolate, on its thread. Blink's main-thread worklets do the
//! same (WorkletGlobalScope(LocalFrame*) is made with ToIsolate(frame) and
//! ThreadType::kMainThread), as WebKit's PaintWorkletGlobalScope runs on the
//! main VM. HTML 11.3.1.1 allows it: a worklet agent's [[CanBlock]] is false,
//! so it may share a thread with the window agent. Blink also gives the
//! worklet an Agent of its own with a v8::MicrotaskQueue of its own; this
//! realm shares its owner's agent - event loop and microtask queue - which
//! nothing observes, since worklet script runs only inside the tasks the
//! worklet host queues. Blink and WebKit run an AudioWorkletGlobalScope on a
//! real-time rendering thread instead; Crane renders no audio (the host media
//! backend does, 2026-10-08), so its audio worklets run here too, until a
//! host renderer gives them a threaded agent of their own - fetching on the
//! owner's thread and handing the source over, as HTML 11.3.2's note says.
//!
//! The realm shares its owner's isolate, so its end must leave the isolate's
//! templates and allocator alone (destroyWorkerRealm frees both, for an
//! isolate about to go).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
// [Exposed] scopes (GlobalScope), as installForScope takes them.
const webidl_helpers = @import("webidl").helpers;
const EngineError = runtime.EngineError;

const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");
const interface_bindings = @import("interface_bindings.zig");
const worker_realm = @import("worker_realm.zig");
const V8Namespace = @import("namespace.zig").V8Namespace;

fn isolateOf(agent: *runtime.Agent) *ffi.Isolate {
    return @ptrCast(@alignCast(agent));
}

/// What differs between the worklet global scope types
/// (`WorkletRealmOptions.WorkletGlobal`): the interface the global object is
/// a platform object of, and the [Exposed] set installed in the realm.
fn GlobalKind(comptime global: runtime.WorkletRealmOptions.WorkletGlobal) type {
    return switch (global) {
        .paint => struct {
            const Interface = interfaces.PaintWorkletGlobalScope;
            const scope: webidl_helpers.GlobalScope = .PaintWorklet;
        },
        .layout => struct {
            const Interface = interfaces.LayoutWorkletGlobalScope;
            const scope: webidl_helpers.GlobalScope = .LayoutWorklet;
        },
        .animation => struct {
            const Interface = interfaces.AnimationWorkletGlobalScope;
            const scope: webidl_helpers.GlobalScope = .AnimationWorklet;
        },
        .audio => struct {
            const Interface = interfaces.AudioWorkletGlobalScope;
            const scope: webidl_helpers.GlobalScope = .AudioWorklet;
        },
    };
}

/// `agent` entered for the scope of a call, if it was not the current one -
/// on the owner's thread it normally is.
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

/// The protocol's `createWorkletRealm`: HTML "create a worklet global scope"
/// step 3 - a new realm in `agent` (the owner's) whose global object is a new
/// object of the worklet global scope type `options.global` names. OWNED:
/// `destroyWorkletRealm`.
pub fn createWorkletRealm(agent: *runtime.Agent, options: runtime.WorkletRealmOptions) EngineError!runtime.WorkletRealm {
    return switch (options.global) {
        inline else => |global| createWorkletRealmOf(GlobalKind(global), agent, options),
    };
}

fn createWorkletRealmOf(comptime Kind: type, agent: *runtime.Agent, options: runtime.WorkletRealmOptions) EngineError!runtime.WorkletRealm {
    // The owner's agent, on the owner's thread: a worklet realm is never made
    // in another agent.
    if (options.owner.agent) |owner_agent| {
        if (owner_agent != agent) return EngineError.OperationFailed;
    }
    const entered = EnteredAgent.enter(agent);
    defer entered.leave();
    const isolate = entered.isolate;
    // Any API call that creates a Local needs a HandleScope.
    const handle_scope = ffi.v8_HandleScope_New(isolate) orelse return EngineError.OperationFailed;
    defer ffi.v8_HandleScope_Dispose(handle_scope);

    // The global object is a platform object of the worklet global scope
    // interface: the context is made from that interface's template (Blink's
    // WorkerOrWorkletScriptController::Initialize, as for a worker).
    const context = ffi.v8_Context_NewWithGlobalConstructor(isolate, worker_realm.globalScopeTemplate(Kind.Interface, isolate)) orelse
        return EngineError.OperationFailed;
    // [code_generation_checks]: eval and Function in it reach the agent's
    // host, when the host checks them.
    @import("protocol_agents.zig").restrictCodeGenerationFromStrings(isolate, context);
    ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);

    return setUp(Kind, isolate, context, options) catch |err| {
        // Undone as destroyWorkletRealm ends a realm: its entry with the
        // context entered, then the context.
        ffi.v8_Context_Enter(context);
        worker_realm.bindGlobalFields(context, null);
        context_manager.removeContext(context);
        ffi.v8_Context_Exit(context);
        ffi.v8_Context_Dispose(context);
        return err;
    };
}

/// The realm in `context`, entered for the call: its runtime context, the
/// interfaces [Exposed] to the worklet, and its global scope.
fn setUp(comptime Kind: type, isolate: *ffi.Isolate, context: *ffi.Context, options: runtime.WorkletRealmOptions) EngineError!runtime.WorkletRealm {
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);

    // No `self`: HTML 11.1.2 gives a WorkletGlobalScope no counterpart to it.

    // The realm's runtime context. Its tasks run on the owner's event loop,
    // which the engine records and never runs; a worklet has no timers.
    const realm = context_manager.getOrCreateWithExternalEventLoop(context, null, options.owner.getOptionalEventLoop(), options.allocator) catch
        return EngineError.OperationFailed;
    // The owner's Browser, and the inbox of the loop its tasks run on.
    realm.browser_scope = options.owner.browser_scope;
    realm.task_sink = options.owner.task_sink;
    // HTML 8.1.3.5 step 1.3: a WorkletGlobalScope's settings object is a
    // secure context ("Worklets can only be created in secure contexts").
    realm.secure_context = true;
    // HTML 11.3.1.3 step 2: the outside settings' API base URL.
    realm.setDocumentUrl(options.api_base_url) catch return EngineError.OutOfMemory;
    if (options.on_realm) |hook| hook(options.data, realm);

    // Every interface exposed to this worklet (WebIDL [Exposed]), and the
    // one namespace Crane binds that is exposed there: console, [Exposed=*]
    // (Console Standard). CSS, TestUtils and the GPU namespaces are not
    // exposed to worklets, and WebAssembly is the engine's own.
    interface_bindings.installForScope(isolate, context, Kind.scope);
    V8Namespace(@import("namespaces").console).registerGlobal(isolate, context, "console");

    // The platform object behind the global, its prototype chain and its own
    // members - after the interface objects, whose prototypes it links.
    const global_scope = try worker_realm.bindGlobalScope(Kind.Interface, isolate, context, realm);
    try worker_realm.recordRealm(isolate, context, realm, global_scope, .worklet);
    return .{ .realm = realm, .global_scope = global_scope };
}

/// The protocol's `destroyWorkletRealm`: what Blink's
/// WorkerOrWorkletScriptController::DisposeContextIfNeeded does for a
/// main-thread worklet - clear the global's native info, then release the
/// per-context data (its wrapper cache and every Instance in it, the global
/// scope last) and the context. The isolate, its templates and allocator,
/// and its other realms stay.
pub fn destroyWorkletRealm(realm: runtime.Context) void {
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx orelse return));
    const agent = realm.agent orelse return;
    const entered = EnteredAgent.enter(agent);
    defer entered.leave();
    const handle_scope = ffi.v8_HandleScope_New(entered.isolate);
    defer if (handle_scope) |scope| ffi.v8_HandleScope_Dispose(scope);
    {
        ffi.v8_Context_Enter(context);
        defer ffi.v8_Context_Exit(context);
        // The global scope is freed just below, after the rest of the
        // realm's wrapper cache (context_manager.removeContextByKey); the
        // global object must not point at it after.
        worker_realm.bindGlobalFields(context, null);
        // The entry is retired, so `engine_ctx` reads null from here on:
        // that is how anything holding the realm across turns learns it has
        // gone. Its realm finalizers are drained first (removeContextByKey).
        context_manager.removeContext(context);
    }
    ffi.v8_Context_Dispose(context);
}
