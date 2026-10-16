//! Implementation for ExtendableEvent interface
//!
//! Spec: Service Workers 4.4 ExtendableEvent
//! https://w3c.github.io/ServiceWorker/#extendableevent-interface
//!
//! An event whose dispatcher waits for the promises waitUntil() adds. The
//! dispatcher - a service worker's thread firing install or activate (or,
//! later, a functional event) - makes the event with its extended lifetime
//! (service_worker.ExtendLifetime: its extend lifetime promises, pending
//! promises count and timed out flag) as a construction argument; one script
//! constructs has none - it is not trusted, and waitUntil() throws before
//! asking (step 1).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const service_worker = @import("service_worker");
const ExtendableEvent = interfaces.ExtendableEvent;
const event_construction = @import("dom").event_construction;

pub const State = ExtendableEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// The extended lifetime its dispatcher gives it (a reference, taken).
pub const construction_args = .{"lifetime"};

pub const InternalState = struct {
    /// Its extended lifetime, or null for an event script constructed.
    lifetime: ?*service_worker.ExtendLifetime,
    allocator: std.mem.Allocator,
};

/// ExtendableEvent's own construction steps: the generated chain runs
/// Event's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const lifetime: ?*service_worker.ExtendLifetime = if (@hasField(@TypeOf(args), "lifetime")) args.lifetime.retain() else null;
    errdefer if (lifetime) |l| l.release();
    const internal = try allocator.create(InternalState);
    internal.* = .{ .lifetime = lifetime, .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// ExtendableEvent's own teardown: the generated chain runs Event's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.lifetime) |lifetime| lifetime.release();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// new ExtendableEvent(type, eventInitDict): DOM's inner event creation
/// steps, then the constructor's own (ExtendableEventInit adds nothing).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ExtendableEventInit)) !*runtime.Instance {
    const instance = try ExtendableEvent.init(ctx.allocator, ctx);
    errdefer ExtendableEvent.deinit(instance);
    const event_init = if (eventInitDict.was_passed) eventInitDict.value.base else dictionaries.EventInit{};
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(event_init));
    return instance;
}

/// Operation: waitUntil (4.4.1) - "add lifetime promise f to this".
pub fn call_waitUntil(instance: *runtime.Instance, f: runtime.JSValue) anyerror!void {
    // 1. Not trusted: InvalidStateError.
    if (!try interfaces.Event.get_isTrusted(instance)) return error.InvalidStateError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    // 2. Not active: InvalidStateError - "if no lifetime extension promise
    // has been added in the task that called the event handlers, calling
    // waitUntil() in subsequent asynchronous tasks will throw".
    const lifetime = internal.lifetime orelse return error.InvalidStateError;
    if (!lifetime.isActive()) return error.InvalidStateError;
    // 3-5.
    const realm = engine.currentRealm() orelse instance.ctx;
    try lifetime.addLifetimePromise(realm, f);
}
