//! Implementation for CloseEvent interface
//!
//! CloseEvent is dispatched when a WebSocket connection is closed.
//! Spec: https://websockets.spec.whatwg.org/#closeevent
//!
//! The CloseEvent interface represents an event sent when a WebSocket connection
//! is closed. This happens when the close() method is called or when the server
//! closes the connection.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CloseEvent = interfaces.CloseEvent;

pub const State = CloseEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for CloseEvent implementation
/// CloseEvent is simple - all data is in the State struct
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up reason string if allocated
    const state = instance.getState(State);
    if (state.own.reason.len > 0) {
        // Note: reason is managed by the event lifecycle
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://websockets.spec.whatwg.org/#dom-closeevent-closeevent
///
/// The CloseEvent(type, eventInitDict) constructor steps are:
/// 1. Set wasClean, code, and reason from eventInitDict (with defaults)
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CloseEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &CloseEvent.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Initialize base Event attributes (Event fields are in state.base.own)
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

        // CloseEvent-specific properties (in state.own)
        state.own.wasClean = init_dict.wasClean orelse false;
        state.own.code = init_dict.code orelse 0;
        state.own.reason = init_dict.reason orelse "";
    } else {
        // Defaults per spec
        state.base.own.bubbles = false;
        state.base.own.cancelable = false;
        state.base.own.composed = false;
        state.own.wasClean = false;
        state.own.code = 0;
        state.own.reason = "";
    }

    // Initialize other Event state
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    return instance;
}

/// Getter for wasClean
/// Spec: https://websockets.spec.whatwg.org/#dom-closeevent-wasclean
///
/// Returns true if the connection closed cleanly; false otherwise.
/// A clean close happens when:
/// - Close frame was received and sent
/// - The closing handshake completed successfully
pub fn get_wasClean(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.wasClean;
}

/// Getter for code
/// Spec: https://websockets.spec.whatwg.org/#dom-closeevent-code
///
/// Returns the WebSocket connection close code provided by the server.
/// This is a numeric value between 1000 and 4999:
/// - 1000: Normal closure
/// - 1001: Going away
/// - 1002: Protocol error
/// - etc. (see RFC 6455 Section 7.4.1)
/// Returns 0 if no code was provided.
pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
    const state = instance.getState(State);
    return state.own.code;
}

/// Getter for reason
/// Spec: https://websockets.spec.whatwg.org/#dom-closeevent-reason
///
/// Returns the WebSocket connection close reason provided by the server.
/// This is a human-readable string explaining why the connection was closed.
/// Returns empty string if no reason was provided.
pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    return state.own.reason;
}

// =============================================================================
// Factory function for creating CloseEvent from WebSocket code
// =============================================================================

/// Create a CloseEvent for internal use (not from constructor)
pub fn createCloseEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    was_clean: bool,
    code: u16,
    reason: []const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &CloseEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Set event type to "close" (Event fields in state.base.own)
    state.base.own.type = try allocator.dupe(u8, "close");
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));
    state.base.own.isTrusted = true; // Internally created events are trusted
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0;

    // Event doesn't bubble and isn't cancelable
    state.base.own.bubbles = false;
    state.base.own.cancelable = false;
    state.base.own.composed = false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    // CloseEvent-specific (in state.own)
    state.own.wasClean = was_clean;
    state.own.code = code;
    // Copy reason to allocator for ownership
    state.own.reason = if (reason.len > 0) try allocator.dupe(u8, reason) else "";

    return instance;
}
