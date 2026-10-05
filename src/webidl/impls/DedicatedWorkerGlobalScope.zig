//! Implementation for DedicatedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.3.2 The DedicatedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/#dedicatedworkerglobalscope
//!
//! The global scope object inside a dedicated worker. Extends WorkerGlobalScope
//! with dedicated worker-specific functionality like postMessage and close.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;

// Ancestors: a DedicatedWorkerGlobalScope IS a WorkerGlobalScope and an
// EventTarget, and reaches their state through their impls.
const WorkerGlobalScopeImpl = @import("WorkerGlobalScope.zig");
const EventTargetImpl = @import("EventTarget.zig");

/// The worker host: the side of "run a worker" that owns this scope's agent.
const worker_host = @import("html").worker_host;

pub const State = DedicatedWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    PostMessageFailed,
    WorkerClosed,
};

/// Internal state for DedicatedWorkerGlobalScope implementation: its name.
pub const InternalState = struct {
    /// Worker name. Owned when `owns_name`.
    name: []const u8 = "",
    owns_name: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        if (self.owns_name) self.allocator.free(self.name);
    }
};

/// Initialize instance (creates the instance)
///
/// Chains to WorkerGlobalScope, and so to EventTarget. When `ctx` is the realm
/// of a worker the host is running, the scope takes that worker's name ("run a
/// worker" step 9: the global scope's name is the options' name).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try WorkerGlobalScopeImpl.init(allocator, StateType, vtable, ctx);
    errdefer WorkerGlobalScopeImpl.deinit(instance);
    if (worker_host.scopeSettings(ctx)) |settings| {
        const internal_state = try allocator.create(InternalState);
        errdefer allocator.destroy(internal_state);
        internal_state.* = .{
            .name = try allocator.dupe(u8, settings.name),
            .owns_name = true,
            .allocator = allocator,
        };
        instance.getState(State).own._internal = internal_state;
    }
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    WorkerGlobalScopeImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for name
///
/// Spec: HTML Standard § 10.2.3.2
/// "The name attribute must return the DedicatedWorkerGlobalScope object's name."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
    }
    return runtime.DOMString.initEmpty();
}

// Event handler IDL attributes (HTML §8.1.8.1): their values live in
// EventTarget's event handler map, where dispatching a MessageEvent at this
// scope finds them.

/// Getter for onrtctransform
pub fn get_onrtctransform(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "rtctransform");
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "message");
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "messageerror");
}

/// Setter for onrtctransform
pub fn set_onrtctransform(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "rtctransform", value);
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "message", value);
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "messageerror", value);
}

/// Operation: requestAnimationFrame
///
/// Spec: HTML Standard § 8.10 AnimationFrameProvider, step 1: "If this is
/// not supported, then throw a NotSupportedError DOMException." A dedicated
/// worker's scope is supported only with frame timing its owner provides,
/// which Crane does not have. Accepting the callback and never running it
/// turned a feature check into a hang.
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.FrameRequestCallback) anyerror!u32 {
    _ = instance;
    _ = callback;
    return error.NotSupportedError;
}

/// Operation: cancelAnimationFrame
///
/// Spec: HTML Standard § 8.10 AnimationFrameProvider, step 1: not supported,
/// as for requestAnimationFrame.
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
    _ = instance;
    _ = handle;
    return error.NotSupportedError;
}

/// Operation: close
///
/// Spec: HTML Standard § 10.2.3.2 close()
/// "The close() method, when invoked, must run these steps:
/// 1. Discard any tasks that have been added to this's relevant agent's event loop's task queues.
/// 2. Set this's closing flag to true."
///
/// The worker host keeps the agent's event loop, so it runs both steps.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    worker_host.closeScope(instance.ctx);
}

/// Operation: postMessage(message, transfer)
///
/// Spec: HTML Standard § 10.2.3.2: "act as if, when invoked, it immediately
/// invoked the respective postMessage(message, transfer) ... on the port
/// that the DedicatedWorkerGlobalScope object's implicit port is entangled
/// with" - the worker host's side of that port.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const allocator = instance.ctx.allocator;
    const objects = try engine.convertToSequenceOfObjects(instance.ctx, transfer, allocator);
    defer {
        for (objects) |object| object.release();
        allocator.free(objects);
    }
    const list = try allocator.alloc(runtime.JSValue, objects.len);
    defer allocator.free(list);
    for (objects, list) |object, *item| item.* = object.value;
    try worker_host.postMessageFromScope(instance.ctx, message, list);
}

/// Operation: postMessage(message, options)
pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!void {
    const transfer: []const runtime.JSValue = if (options.wasPassed()) (options.getValue().transfer orelse &.{}) else &.{};
    try worker_host.postMessageFromScope(instance.ctx, message, transfer);
}
