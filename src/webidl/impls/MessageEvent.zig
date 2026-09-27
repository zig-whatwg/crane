//! Implementation for MessageEvent interface
//!
//! MessageEvent is dispatched when a message is received through various APIs:
//! - WebSocket: when a message is received from the server
//! - postMessage: when a message is posted to a window/worker
//! - Server-Sent Events: when an event is received
//! - BroadcastChannel: when a message is received on the channel
//!
//! Spec: https://html.spec.whatwg.org/multipage/comms.html#messageevent
//!
//! For WebSocket specifically:
//! - data contains the message payload (string or binary)
//! - origin is the URL of the WebSocket server
//! - lastEventId is empty string (not used for WebSocket)
//! - source is null (not used for WebSocket)
//! - ports is an empty array (not used for WebSocket)

const std = @import("std");
const log = std.log.scoped(.message_event);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const MessageEvent = interfaces.MessageEvent;

pub const State = MessageEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for MessageEvent implementation
pub const InternalState = struct {
    /// Whether we own the origin string (should free on deinit)
    owns_origin: bool = false,
    /// Whether `data` is a handle this event releases on deinit - one an
    /// Engine operation handed over as OWNED. Only `createPostMessageEvent`
    /// hands one over; every other path stores a handle that somebody else
    /// frees.
    owns_data_handle: bool = false,
    /// Whether `ports` is the frozen array `get_ports` made for this event:
    /// OWNED, released on deinit.
    owns_ports_handle: bool = false,
    /// The event's ports, as the MessagePort instances they are: the frozen
    /// array `ports` returns is made from them on first read. Owned slice
    /// (ctx.allocator); the ports themselves are not.
    ports: []*runtime.Instance = &.{},
};

/// Release a handle an Engine operation handed this event as OWNED.
fn releaseHandle(ctx: runtime.Context, value: runtime.JSValue) void {
    const engine = ctx.getEngine() orelse return;
    if (engine.releaseValue) |release| release(value);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const state = instance.getState(State);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = .{};
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    var state = instance.getState(State);

    // The handles this event owns: a deserialized postMessage payload, and
    // the frozen ports array.
    if (state.own._internal) |internal| {
        if (internal.owns_data_handle and state.own.data == .handle) {
            releaseHandle(instance.ctx, state.own.data);
            state.own.data = runtime.JSValue.jsUndefined;
        }
        internal.owns_data_handle = false;
        if (internal.owns_ports_handle and state.own.ports == .handle) {
            releaseHandle(instance.ctx, state.own.ports);
            state.own.ports = runtime.JSValue.jsUndefined;
        }
        internal.owns_ports_handle = false;
        if (internal.ports.len > 0) instance.ctx.allocator.free(internal.ports);
        internal.ports = &.{};
    }

    // Clean up the cloned JSValue data (if it's an owned string)
    // This was cloned in call_constructor to take ownership using ctx.allocator
    state.own.data.deinit(instance.ctx.allocator);

    if (state.own._internal) |internal| {
        // Free origin string if we own it (allocated in createPostMessageEvent)
        if (internal.owns_origin and state.own.origin.len > 0) {
            instance.ctx.allocator.free(state.own.origin);
        }
    }

    // Release MessageEvent's OWN internal block. The parent releases the Event-level
    // one, which on a MessageEvent instance is a different allocation.
    if (state.own._internal) |internal| {
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }

    // Call parent Event deinit to clean up base class resources (including state.base.own.type)
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-messageevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.MessageEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Initialize base Event attributes (Event fields in state.base.own)

    state.base.own.type = try @"type".clone(ctx.allocator);
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));
    state.base.own.isTrusted = false;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0; // NONE

    // Get init dict values with defaults per spec
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // Event properties from base EventInit
        state.base.own.bubbles = init_dict.base.bubbles orelse false;
        state.base.own.cancelable = init_dict.base.cancelable orelse false;
        state.base.own.composed = init_dict.base.composed orelse false;

        // MessageEvent-specific properties (in state.own)
        // Use JSValue.jsUndefined for undefined data
        // IMPORTANT: Clone the JSValue to take ownership. The argument cleanup code
        // will free the original string buffer after the constructor returns.
        state.own.data = if (init_dict.data) |data| try keepData(ctx, instance, data) else runtime.JSValue.jsUndefined;
        // The dictionary's string is freed when the constructor returns.
        if (init_dict.origin) |origin| {
            if (origin.len > 0) {
                state.own.origin = try ctx.allocator.dupe(u8, origin);
                if (state.own._internal) |internal| internal.owns_origin = true;
            } else {
                state.own.origin = "";
            }
        } else {
            state.own.origin = "";
        }
        state.own.lastEventId = if (init_dict.lastEventId) |id| id else runtime.DOMString.initEmpty();
        // source requires more complex handling
        state.own.source = null;
        // "ports": a frozen array of the init dictionary's ports, made from
        // these on first read (`get_ports`).
        if (init_dict.ports) |ports| {
            if (ports.len > 0) {
                if (state.own._internal) |internal| internal.ports = try ctx.allocator.dupe(*runtime.Instance, ports);
            }
        }
    } else {
        // Defaults per spec
        state.base.own.bubbles = false;
        state.base.own.cancelable = false;
        state.base.own.composed = false;
        state.own.data = runtime.JSValue.jsUndefined; // Use jsUndefined for undefined
        state.own.origin = "";
        state.own.lastEventId = runtime.DOMString.initEmpty();
        state.own.source = null;
    }

    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    // Create the INHERITED Event internal state and set the initialized flag.
    // Without it dispatchEvent throws InvalidStateError, so the event can be
    // constructed but never dispatched. Same thing MouseEvent does by hand.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// The event's own hold on `data` (borrowed from the dictionary): a string
/// is copied, and a script value is retained through the Engine table - OWNED
/// by the event, released in deinit - so it lives as long as the event, not
/// as long as whoever handed it over.
fn keepData(ctx: runtime.Context, instance: *runtime.Instance, data: runtime.JSValue) !runtime.JSValue {
    switch (data) {
        .handle, .instance => {
            const engine = ctx.getEngine() orelse return data.clone(ctx.allocator);
            const retain = engine.retainValue orelse return data.clone(ctx.allocator);
            const held = try retain(ctx, data);
            if (instance.getState(State).own._internal) |internal| internal.owns_data_handle = true;
            return held;
        },
        else => return data.clone(ctx.allocator),
    }
}

/// Getter for data
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-data
///
/// For WebSocket:
/// - Returns a DOMString if binaryType is "blob" and message was text
/// - Returns a Blob if binaryType is "blob" and message was binary
/// - Returns an ArrayBuffer if binaryType is "arraybuffer" and message was binary
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    // The event keeps what it holds: a handle goes out borrowed, and the
    // binding reads it and leaves it.
    return switch (state.own.data) {
        .handle => |h| .{ .handle = .{ .ptr = h.ptr, .needs_disposal = false, .handle_scope = h.handle_scope } },
        else => state.own.data,
    };
}

/// Getter for origin
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-origin
///
/// For WebSocket, this is the URL of the WebSocket server.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    log.debug("[MessageEvent.get_origin] value=\"{s}\"\n", .{state.own.origin});
    // The binding frees a returned USVString, so it gets a copy. Returning the
    // field itself freed it on the first read of `e.origin`; the second read
    // was a use-after-free and `deinit` then freed it again.
    if (state.own.origin.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, state.own.origin);
}

/// Getter for lastEventId
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-lasteventid
///
/// For WebSocket, this is always an empty string.
/// This is used by Server-Sent Events.
pub fn get_lastEventId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    log.debug("[MessageEvent.get_lastEventId] called\n", .{});
    // Return as interned to avoid double-free (state owns the string)
    return runtime.DOMString.initInterned(state.own.lastEventId.asSlice());
}

/// Getter for source
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-source
///
/// For WebSocket, this is always null.
/// This is used by postMessage to identify the sending window/worker.
pub fn get_source(instance: *runtime.Instance) anyerror!?typedefs.MessageEventSource {
    const state = instance.getState(State);
    log.debug("[MessageEvent.get_source] called\n", .{});
    return state.own.source;
}

/// Getter for ports
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-ports
///
/// "The ports attribute must return the value it was initialized to": a
/// FROZEN array of the ports transferred with the message (or given to the
/// constructor) - empty when there were none. It is one array for the life
/// of the event, so `e.ports === e.ports`; the event owns it and releases it
/// in deinit.
pub fn get_ports(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return runtime.JSValue.jsUndefined;
    if (!internal.owns_ports_handle) {
        const engine = instance.ctx.getEngine() orelse return error.NoEngine;
        const create = engine.createFrozenArrayOfPlatformObjects orelse return error.NotSupported;
        state.own.ports = try create(instance.ctx, internal.ports);
        internal.owns_ports_handle = true;
    }
    // Borrowed: the event keeps its array.
    return switch (state.own.ports) {
        .handle => |h| .{ .handle = .{ .ptr = h.ptr, .needs_disposal = false, .handle_scope = h.handle_scope } },
        else => state.own.ports,
    };
}

/// Operation: initMessageEvent (legacy)
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-initmessageevent
///
/// This is a legacy method for initializing MessageEvent.
/// New code should use the constructor instead.
pub fn call_initMessageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), data: webidl.Opt(runtime.JSValue), origin: webidl.Opt(runtime.USVString), lastEventId: webidl.Opt(runtime.DOMString), source: webidl.Opt(?typedefs.MessageEventSource), ports: webidl.Opt(runtime.JSValue)) anyerror!void {
    const state = instance.getState(State);

    // Update event properties (Event fields in state.base.own)
    state.base.own.type = @"type";
    state.base.own.bubbles = if (bubbles.was_passed) bubbles.value else false;
    state.base.own.cancelable = if (cancelable.was_passed) cancelable.value else false;

    // MessageEvent fields in state.own. What the event held before is let
    // go, and it takes its own hold on the new values: the arguments are the
    // binding's, freed when this returns.
    if (state.own._internal) |internal| {
        if (internal.owns_data_handle and state.own.data == .handle) releaseHandle(instance.ctx, state.own.data);
        internal.owns_data_handle = false;
        if (internal.owns_origin and state.own.origin.len > 0) instance.ctx.allocator.free(state.own.origin);
        internal.owns_origin = false;
    }
    state.own.data.deinit(instance.ctx.allocator);
    state.own.data = if (data.was_passed) try keepData(instance.ctx, instance, data.value) else runtime.JSValue.jsUndefined;
    state.own.origin = "";
    if (origin.was_passed and origin.value.len > 0) {
        state.own.origin = try instance.ctx.allocator.dupe(u8, origin.value);
        if (state.own._internal) |internal| internal.owns_origin = true;
    }
    state.own.lastEventId = if (lastEventId.was_passed) lastEventId.value else runtime.DOMString.initEmpty();
    state.own.source = if (source.was_passed) source.value else null;

    // ports handling would require more complex logic
    _ = ports;
}

// =============================================================================
// Factory functions for events the engine fires
// =============================================================================

/// Create the MessageEvent that HTML's "window post message steps" fire:
/// `message` at step 8.7, or `messageerror` when deserialization fails at
/// step 8.4.
///
/// Takes ownership of `data` if it succeeds - an owned string is freed, and a
/// Global handle disposed, when the event is. If it fails the caller still
/// owns `data`: everything that can fail happens before `data` is stored.
pub fn createPostMessageEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    event_type: []const u8,
    data: runtime.JSValue,
    origin_str: []const u8,
    source_window: ?*runtime.Instance,
) !*runtime.Instance {
    const instance = try init(allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Event fields (state.base.own). `event_type` is a literal, so interning
    // it borrows nothing that can go away.
    state.base.own.type = runtime.DOMString.initInterned(event_type);
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));
    state.base.own.isTrusted = true; // Browser-initiated
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0;

    state.base.own.bubbles = false;
    state.base.own.cancelable = false;
    state.base.own.composed = false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    // MessageEvent fields (state.own)
    state.own.data = runtime.JSValue.jsUndefined;
    state.own.origin = try allocator.dupe(u8, origin_str);
    if (state.own._internal) |internal| internal.owns_origin = true;
    state.own.lastEventId = runtime.DOMString.initEmpty();

    // Set source to the posting window (WindowProxy)
    // MessageEventSource is a tagged union type that can be WindowProxy, MessagePort, or ServiceWorker
    state.own.source = if (source_window) |sw| typedefs.MessageEventSource{ .window_proxy = @ptrCast(sw) } else null;

    // The inherited Event internal state and its initialized flag. Without
    // them dispatchEvent throws InvalidStateError - which is what every
    // window.postMessage call did, synchronously, before this line existed.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    // Nothing can fail from here, so the event takes `data`.
    state.own.data = data;
    if (data == .handle) {
        if (state.own._internal) |internal| internal.owns_data_handle = true;
    }

    return instance;
}
