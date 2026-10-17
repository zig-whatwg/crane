//! Implementation for FetchEvent interface
//!
//! Spec: Service Workers 4.6 FetchEvent
//! https://w3c.github.io/ServiceWorker/#fetchevent-interface
//!
//! The `fetch` event a service worker's global gets from Handle Fetch: an
//! ExtendableEvent (its extended lifetime is ExtendableEvent's construction
//! argument) with the request, the client ids, `handled` and
//! `preloadResponse`. The worker's thread (src/service_worker/fetch_event.zig)
//! makes it with `fetch` - which carries the responder respondWith()
//! answers Handle Fetch through; one script constructs has none, and
//! respondWith() on it only extends its lifetime, as it does in browsers.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const service_worker = @import("service_worker");
const FetchEvent = interfaces.FetchEvent;

pub const State = FetchEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// What the user agent's event is made with
/// (service_worker.fetch_event.FetchEventInit), BORROWED.
pub const construction_args = .{"fetch"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The Request object, held: the event may be all that refers to it.
    request: ?*runtime.Instance = null,
    request_hold: ?engine.Owned = null,
    preload_response: ?engine.Owned = null,
    handled: ?engine.Owned = null,
    /// OWNED.
    client_id: []u8 = &.{},
    resulting_client_id: []u8 = &.{},
    replaces_client_id: []u8 = &.{},
    /// The user agent's fetch respondWith() answers (a reference); null for
    /// an event script constructed.
    responder: ?*service_worker.fetch_event.Responder = null,
    /// Its respond-with entered flag, for an event with no responder.
    respond_with_entered: bool = false,
};

/// FetchEvent's own construction steps: the generated chain runs
/// ExtendableEvent's (and Event's) first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    if (!@hasField(@TypeOf(args), "fetch")) return;
    errdefer releaseAll(internal);
    const init: service_worker.fetch_event.FetchEventInit = args.fetch;
    const ctx = instance.ctx;
    try keepRequest(ctx, internal, init.request);
    internal.preload_response = try engine.retainValue(ctx, init.preload_response);
    internal.handled = try engine.retainValue(ctx, init.handled);
    internal.client_id = try allocator.dupe(u8, init.client_id);
    internal.resulting_client_id = try allocator.dupe(u8, init.resulting_client_id);
    internal.replaces_client_id = try allocator.dupe(u8, init.replaces_client_id);
    internal.responder = init.responder.retain();
}

/// FetchEvent's own teardown: the generated chain runs ExtendableEvent's
/// after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    releaseAll(internal);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn releaseAll(internal: *InternalState) void {
    const allocator = internal.allocator;
    if (internal.request_hold) |hold| hold.release();
    internal.request_hold = null;
    internal.request = null;
    if (internal.preload_response) |hold| hold.release();
    internal.preload_response = null;
    if (internal.handled) |hold| hold.release();
    internal.handled = null;
    allocator.free(internal.client_id);
    internal.client_id = &.{};
    allocator.free(internal.resulting_client_id);
    internal.resulting_client_id = &.{};
    allocator.free(internal.replaces_client_id);
    internal.replaces_client_id = &.{};
    if (internal.responder) |responder| responder.release();
    internal.responder = null;
}

fn keepRequest(ctx: runtime.Context, internal: *InternalState, request: *runtime.Instance) !void {
    internal.request_hold = try engine.retainValue(ctx, runtime.JSValue.fromInstance(request));
    internal.request = request;
}

/// new FetchEvent(type, eventInitDict): DOM's inner event creation steps,
/// then the dictionary's members - preloadResponse "a promise resolved with
/// undefined" and handled "a pending promise" when not given (4.6.2,
/// 4.6.6), the client ids the empty string.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.FetchEventInit) !*runtime.Instance {
    const instance = try FetchEvent.init(ctx.allocator, ctx);
    errdefer FetchEvent.deinit(instance);
    try dom.event_construction.innerEventCreationSteps(instance, @"type", dom.event_construction.eventInitFrom(eventInitDict.base.base));
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const allocator = internal.allocator;
    try keepRequest(ctx, internal, eventInitDict.request);
    internal.preload_response = if (eventInitDict.preloadResponse) |value|
        try engine.retainValue(ctx, value)
    else
        try engine.createResolvedPromise(ctx, runtime.JSValue.jsUndefined);
    internal.handled = if (eventInitDict.handled) |value| try engine.retainValue(ctx, value) else blk: {
        var capability = try engine.createPromise(ctx);
        defer engine.releasePromiseCapability(&capability);
        break :blk try engine.retainValue(ctx, capability.promise);
    };
    if (eventInitDict.clientId) |id| internal.client_id = try allocator.dupe(u8, id.asSlice());
    if (eventInitDict.resultingClientId) |id| internal.resulting_client_id = try allocator.dupe(u8, id.asSlice());
    if (eventInitDict.replacesClientId) |id| internal.replaces_client_id = try allocator.dupe(u8, id.asSlice());
    return instance;
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

/// Getter for request (4.6.1): the value it was initialized to.
pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = try internalOf(instance);
    return internal.request orelse error.InvalidStateError;
}

/// Getter for preloadResponse (4.6.2).
pub fn get_preloadResponse(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    const hold = internal.preload_response orelse return runtime.JSValue.jsUndefined;
    // The event keeps its own; the binding gets a hold of its own.
    return (try engine.retainValue(instance.ctx, hold.value)).take();
}

/// Getter for clientId (4.6.3).
pub fn get_clientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try internalOf(instance);
    return runtime.DOMString.initInterned(internal.client_id);
}

/// Getter for resultingClientId (4.6.4).
pub fn get_resultingClientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try internalOf(instance);
    return runtime.DOMString.initInterned(internal.resulting_client_id);
}

/// Getter for replacesClientId (4.6.5).
pub fn get_replacesClientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try internalOf(instance);
    return runtime.DOMString.initInterned(internal.replaces_client_id);
}

/// Getter for handled (4.6.6).
pub fn get_handled(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    const hold = internal.handled orelse return runtime.JSValue.jsUndefined;
    return (try engine.retainValue(instance.ctx, hold.value)).take();
}

/// Operation: respondWith (4.6.7).
pub fn call_respondWith(instance: *runtime.Instance, r: runtime.JSValue) anyerror!void {
    const internal = try internalOf(instance);
    // 2. The event is not being dispatched: InvalidStateError.
    if (!dom.event_construction.dispatchFlag(instance)) return error.InvalidStateError;
    // 3. respondWith() was called already: InvalidStateError.
    const entered = if (internal.responder) |responder| responder.respond_with_entered else internal.respond_with_entered;
    if (entered) return error.InvalidStateError;
    // 4. Add lifetime promise r to event - waitUntil()'s steps, with its
    // checks (an untrusted or inactive event throws InvalidStateError).
    try interfaces.ExtendableEvent.call_waitUntil(instance, r);
    // 5. The stop propagation and stop immediate propagation flags.
    try interfaces.Event.call_stopImmediatePropagation(instance);
    // 6-10. The flags, and the reactions that answer the fetch.
    const responder = internal.responder orelse {
        internal.respond_with_entered = true;
        return;
    };
    const realm = engine.currentRealm() orelse instance.ctx;
    try responder.respondWith(realm, r);
}
