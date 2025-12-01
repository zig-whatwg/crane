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
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const MessageEvent = interfaces.MessageEvent;

pub const State = MessageEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Data type for MessageEvent.data
/// Per spec, data can be any JavaScript value (any type).
/// For WebSocket, it's either DOMString (text) or Blob/ArrayBuffer (binary).
pub const MessageData = union(enum) {
    /// Text message (UTF-8 string)
    string: runtime.DOMString,
    /// Binary message as raw bytes (to be converted to Blob or ArrayBuffer)
    binary: []const u8,
    /// Generic any value (for non-WebSocket use)
    any: *const anyopaque,
};

/// Internal state for MessageEvent implementation
pub const InternalState = struct {
    /// The actual message data (typed)
    message_data: ?MessageData = null,
    /// Whether we own the binary data (should free on deinit)
    owns_binary: bool = false,
};

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
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.owns_binary) {
            if (internal.message_data) |data| {
                switch (data) {
                    .binary => |b| {
                        // Binary data owned by us should be freed
                        _ = b;
                    },
                    else => {},
                }
            }
        }
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-messageevent
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.MessageEventInit)) !*runtime.Instance {
    const instance = try init(allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Initialize base Event attributes (Event fields in state.base.own)
    state.base.own.type = try @"type".clone(allocator);
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));
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
        state.own.data = init_dict.data orelse @as(*const anyopaque, @ptrFromInt(1)); // Use non-null sentinel
        state.own.origin = init_dict.origin orelse "";
        state.own.lastEventId = if (init_dict.lastEventId) |id| id else runtime.DOMString.initEmpty();
        // source and ports require more complex handling
        state.own.source = null;
    } else {
        // Defaults per spec
        state.base.own.bubbles = false;
        state.base.own.cancelable = false;
        state.base.own.composed = false;
        state.own.data = @as(*const anyopaque, @ptrFromInt(1)); // Use non-null sentinel for "undefined"
        state.own.origin = "";
        state.own.lastEventId = runtime.DOMString.initEmpty();
        state.own.source = null;
    }

    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    return instance;
}

/// Getter for data
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-data
///
/// For WebSocket:
/// - Returns a DOMString if binaryType is "blob" and message was text
/// - Returns a Blob if binaryType is "blob" and message was binary
/// - Returns an ArrayBuffer if binaryType is "arraybuffer" and message was binary
pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
    const state = instance.getState(State);
    return state.own.data;
}

/// Getter for origin
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-origin
///
/// For WebSocket, this is the URL of the WebSocket server.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    return state.own.origin;
}

/// Getter for lastEventId
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-lasteventid
///
/// For WebSocket, this is always an empty string.
/// This is used by Server-Sent Events.
pub fn get_lastEventId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.lastEventId;
}

/// Getter for source
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-source
///
/// For WebSocket, this is always null.
/// This is used by postMessage to identify the sending window/worker.
pub fn get_source(instance: *runtime.Instance) anyerror!?typedefs.MessageEventSource {
    const state = instance.getState(State);
    return state.own.source;
}

/// Getter for ports
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-ports
///
/// For WebSocket, this is always an empty frozen array.
/// This is used by postMessage for transferring MessagePorts.
pub fn get_ports(instance: *runtime.Instance) anyerror!*const anyopaque {
    const state = instance.getState(State);
    // Return the ports array (empty for WebSocket)
    return @ptrCast(&state.own.ports);
}

/// Operation: initMessageEvent (legacy)
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-initmessageevent
///
/// This is a legacy method for initializing MessageEvent.
/// New code should use the constructor instead.
pub fn call_initMessageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), data: webidl.Opt(*const anyopaque), origin: webidl.Opt(runtime.USVString), lastEventId: webidl.Opt(runtime.DOMString), source: webidl.Opt(?typedefs.MessageEventSource), ports: webidl.Opt(*const anyopaque)) anyerror!void {
    const state = instance.getState(State);

    // Update event properties (Event fields in state.base.own)
    state.base.own.type = @"type";
    state.base.own.bubbles = if (bubbles.was_passed) bubbles.value else false;
    state.base.own.cancelable = if (cancelable.was_passed) cancelable.value else false;

    // MessageEvent fields in state.own
    state.own.data = if (data.was_passed) data.value else @as(*const anyopaque, @ptrFromInt(1));
    state.own.origin = if (origin.was_passed) origin.value else "";
    state.own.lastEventId = if (lastEventId.was_passed) lastEventId.value else runtime.DOMString.initEmpty();
    state.own.source = if (source.was_passed) source.value else null;

    // ports handling would require more complex logic
    _ = ports;
}

// =============================================================================
// Factory functions for creating MessageEvent from WebSocket code
// =============================================================================

/// Create a MessageEvent for a text message (WebSocket)
pub fn createTextMessageEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    text_data: []const u8,
    origin: []const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Set event type to "message" (Event fields in state.base.own)
    state.base.own.type = try allocator.dupe(u8, "message");
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));
    state.base.own.isTrusted = true;
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

    // Store the text data as a DOMString (copy for ownership)
    const text_string = try allocator.dupe(u8, text_data);
    state.own.data = @ptrCast(text_string.ptr);

    // Set origin (copy for ownership)
    state.own.origin = try allocator.dupe(u8, origin);
    state.own.lastEventId = runtime.DOMString.initEmpty();
    state.own.source = null;

    // Store in internal state for proper type tracking
    if (state.own._internal) |internal| {
        internal.message_data = .{ .string = text_string };
    }

    return instance;
}

/// Create a MessageEvent for a binary message (WebSocket)
pub fn createBinaryMessageEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    binary_data: []const u8,
    origin_str: []const u8,
    owns_data: bool,
) !*runtime.Instance {
    const instance = try init(allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Set event type to "message" (Event fields in state.base.own)
    state.base.own.type = try allocator.dupe(u8, "message");
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));
    state.base.own.isTrusted = true;
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

    // For binary data, the actual conversion to Blob/ArrayBuffer
    // happens in the JS binding layer based on binaryType (MessageEvent fields in state.own)
    state.own.data = @ptrCast(binary_data.ptr);

    // Set origin (copy for ownership)
    state.own.origin = try allocator.dupe(u8, origin_str);
    state.own.lastEventId = runtime.DOMString.initEmpty();
    state.own.source = null;

    // Store in internal state
    if (state.own._internal) |internal| {
        internal.message_data = .{ .binary = binary_data };
        internal.owns_data = owns_data;
    }

    return instance;
}
