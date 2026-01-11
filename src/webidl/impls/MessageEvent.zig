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

// V8 engine for Global handle disposal
// Note: This direct import is needed for proper GC cleanup of MessageEvent.data
// which stores a V8 Global handle when the event carries JSON-parsed data.
// Ideally this would go through EngineInterface, but that abstraction doesn't
// currently support handle disposal.
const v8_engine = @import("v8");

pub const State = MessageEvent.State;

/// Static sentinel value for "undefined" data - avoids using @ptrFromInt
var undefined_sentinel: u8 = 0;

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
    /// V8 Global handle for ports array (persists beyond HandleScope)
    ports_global: v8_engine.OptionalGlobalHandle = null,
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

    // Clean up state.own.data based on its variant:
    // - .handle: Dispose V8 Global handle if needs_disposal is true
    // - .string: Free owned string buffer
    // This is critical for preventing memory leaks and use-after-free crashes.
    switch (state.own.data) {
        .handle => |h| {
            if (h.needs_disposal) {
                v8_engine.ffi.v8_Global_Dispose(@ptrCast(h.ptr));
            }
        },
        .string => |s| {
            if (s.owned and s.data.len > 0) {
                // String data was cloned in constructor - free it
                instance.ctx.allocator.free(s.data);
            }
        },
        else => {
            // Other JSValue variants (undefined, null, boolean, number, instance)
            // don't require cleanup
        },
    }

    if (state.own._internal) |internal| {
        // Dispose the ports Global handle if set
        if (internal.ports_global) |ports_handle| {
            ports_handle.dispose();
        }

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

    // Call parent Event deinit to clean up base class resources (including state.base.own.type)
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-messageevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.MessageEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state for Event (required for flags like dispatch_flag, initialized_flag, path)
    // This is stored in the Event's part of the state hierarchy (state.base.own._internal)
    // MessageEvent -> Event, so we use state.base.own._internal
    const EventImpl = @import("Event.zig");
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const arena = ArenaAllocator.get();
    const event_internal = try arena.create(EventImpl.InternalState);
    event_internal.* = EventImpl.InternalState.init(ctx.allocator);
    state.base.own._internal = event_internal;

    // Set the initialized flag
    event_internal.initialized_flag = true;

    // Initialize base Event attributes (Event fields in state.base.own)
    state.base.own.type = try @"type".clone(ctx.allocator);
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
        // Clone the data to take ownership - the original will be freed by freeConvertedValue
        // after the constructor returns, so we must have our own copy
        state.own.data = if (init_dict.data) |data|
            try data.clone(ctx.allocator)
        else
            runtime.JSValue.jsUndefined;
        state.own.origin = init_dict.origin orelse "";
        state.own.lastEventId = if (init_dict.lastEventId) |id| id else runtime.DOMString.initEmpty();
        // source and ports require more complex handling
        state.own.source = null;
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

    return instance;
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
    return state.own.source;
}

/// Getter for ports
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-ports
///
/// Returns an array of MessagePort objects representing transferred ports.
/// For WebSocket, this is always an empty array.
/// For MessagePort.postMessage with transfer list, this contains the transferred ports.
pub fn get_ports(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    return state.own.ports;
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

    // MessageEvent fields in state.own
    state.own.data = if (data.was_passed) data.value else runtime.JSValue.jsUndefined;
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
    // Create a proper JSValue.string instead of invalid @ptrCast
    state.own.data = .{ .string = .{ .data = text_string, .owned = true } };

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
    // Create a proper JSValue.string for binary data (will be converted to ArrayBuffer/Blob by caller)
    const binary_copy = if (owns_data) binary_data else try allocator.dupe(u8, binary_data);
    state.own.data = .{ .string = .{ .data = binary_copy, .owned = true } };

    // Set origin (copy for ownership)
    state.own.origin = try allocator.dupe(u8, origin_str);
    state.own.lastEventId = runtime.DOMString.initEmpty();
    state.own.source = null;

    // Store in internal state
    if (state.own._internal) |internal| {
        internal.message_data = .{ .binary = binary_data };
        internal.owns_binary = owns_data;
    }

    return instance;
}

/// Create a MessageEvent for a MessagePort message (postMessage)
///
/// Spec: HTML Standard section 9.4.1
/// - data: The message payload (any JavaScript value)
/// - origin: Empty string for ports (per spec)
/// - source: null for ports
/// - ports: Array of transferred ports (JSValue containing array, or undefined for empty)
pub fn createPortMessageEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    data: runtime.JSValue,
    ports: runtime.JSValue,
) !*runtime.Instance {
    const instance = try init(allocator, State, &MessageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state for Event (required for flags like dispatch_flag, initialized_flag, path)
    const EventImpl = @import("Event.zig");
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const arena = ArenaAllocator.get();
    const event_internal = try arena.create(EventImpl.InternalState);
    event_internal.* = EventImpl.InternalState.init(ctx.allocator);
    state.base.own._internal = event_internal;
    event_internal.initialized_flag = true;

    // Set event type to "message" (Event fields in state.base.own)
    state.base.own.type = try typedefs.DOMString.initDupe(allocator, "message");
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));
    state.base.own.isTrusted = true; // System-generated event
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

    // MessageEvent-specific fields (state.own)
    // Clone the data to take ownership
    state.own.data = try data.clone(allocator);
    state.own.origin = ""; // Empty string for ports per spec
    state.own.lastEventId = runtime.DOMString.initEmpty();
    state.own.source = null; // null for ports per spec

    // For ports, we need to persist the V8 handle as a Global handle
    // because the callback's Global handles are disposed after the callback returns.
    // Store the Global handle in internal state and mark ports as having a global handle.
    switch (ports) {
        .handle => |h| {
            // Get the current isolate
            const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
                state.own.ports = runtime.JSValue.jsUndefined;
                return instance;
            };

            // h.ptr is ALREADY a Global<Value>* from v8_FunctionCallbackInfo_GetArgument.
            // We need to create our OWN Global handle because the callback's Global
            // will be disposed when the callback returns.
            //
            // First get a Local from the existing Global, then create a new Global.
            const local_value = v8_engine.ffi.v8_Global_Get(isolate, @ptrCast(h.ptr)) orelse {
                state.own.ports = runtime.JSValue.jsUndefined;
                return instance;
            };

            // Now create our own Global handle from the Local
            if (v8_engine.GlobalHandle.create(isolate, local_value)) |global_handle| {
                // Store in internal state for lifetime management
                if (state.own._internal) |internal| {
                    internal.ports_global = global_handle;
                }
                // Store a handle with the Global pointer for get_ports()
                state.own.ports = runtime.JSValue{
                    .handle = .{ .ptr = global_handle.ptr, .needs_disposal = false },
                };
            } else {
                state.own.ports = runtime.JSValue.jsUndefined;
            }
        },
        else => {
            state.own.ports = ports;
        },
    }

    return instance;
}
