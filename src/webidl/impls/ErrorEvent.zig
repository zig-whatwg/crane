//! Implementation for ErrorEvent interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#errorevent
//! HTML Standard §8.1.6.1 Runtime script errors
//!
//! The ErrorEvent interface represents errors from script execution.
//! It provides message, filename, line number, column number, and error value.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const ErrorEvent = interfaces.ErrorEvent;

pub const State = ErrorEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for ErrorEvent
/// Stores the error-specific attributes initialized from ErrorEventInit
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The error message
    /// Spec: "represents the error message"
    message: runtime.DOMString,

    /// The URL of the script where the error occurred
    /// Spec: "represents the URL of the script in which the error originally occurred"
    /// Note: USVString is []const u8 in Zig
    filename: []const u8,

    /// The line number where the error occurred
    /// Spec: "represents the line number where the error occurred in the script"
    lineno: u32,

    /// The column number where the error occurred
    /// Spec: "represents the column number where the error occurred in the script"
    colno: u32,

    /// The error object (may be null)
    /// Spec: "represents the error (e.g., the exception object in the case of an uncaught exception)"
    @"error": ?*const anyopaque,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .message = runtime.DOMString.initEmpty(),
            .filename = "", // Empty string for USVString
            .lineno = 0,
            .colno = 0,
            .@"error" = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // InternalState is allocated with ArenaAllocator, which batch-frees during GC sweep
        // We only need to clean up any non-arena allocations here
        _ = self;
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

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
    const state = instance.getState(State);

    // Clean up ErrorEvent-specific resources
    if (state.own._internal) |internal| {
        // Free owned strings
        internal.message.deinit(internal.allocator);
        if (internal.filename.len > 0) {
            internal.allocator.free(internal.filename);
        }
        internal.deinit();
    }

    // Call parent Event deinit to clean up base class resources (including state.base.own.type)
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#errorevent
///
/// The ErrorEvent(type, eventInitDict) constructor steps are:
/// 1. Set the Event-related attributes (type, bubbles, cancelable, composed)
/// 2. Set the ErrorEvent-specific attributes from eventInitDict
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ErrorEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &ErrorEvent.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Create internal state
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(ctx.allocator);
    state.own._internal = internal;

    // Initialize Event base class attributes (Event fields are in state.base.own)
    // Get EventInit from ErrorEventInit.base
    const event_init = if (eventInitDict.was_passed) eventInitDict.value.base else dictionaries.EventInit{};
    const bubbles = event_init.bubbles orelse false;
    const cancelable = event_init.cancelable orelse false;
    const composed = event_init.composed orelse false;

    // Store event type - clone the string to ensure we own it
    state.base.own.type = try @"type".clone(ctx.allocator);

    // Initialize Event attributes (all in state.base.own)
    state.base.own.bubbles = bubbles;
    state.base.own.cancelable = cancelable;
    state.base.own.composed = composed;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = interfaces.Event.get_NONE();
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;
    state.base.own.isTrusted = false;
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

    // Initialize ErrorEvent-specific attributes from eventInitDict
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // message defaults to ""
        if (init_dict.message) |msg| {
            internal.message = try msg.clone(ctx.allocator);
        }

        // filename defaults to "" (USVString is []const u8)
        if (init_dict.filename) |fname| {
            internal.filename = try ctx.allocator.dupe(u8, fname);
        }

        // lineno defaults to 0
        if (init_dict.lineno) |line| {
            internal.lineno = line;
        }

        // colno defaults to 0
        if (init_dict.colno) |col| {
            internal.colno = col;
        }

        // error defaults to undefined (null in our representation)
        if (init_dict.@"error") |err| {
            internal.@"error" = err.toAnyopaque();
        }
    }

    return instance;
}

/// Getter for message
/// Spec: "The message attribute must return the value it was initialized to."
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.message.asSlice());
}

/// Getter for filename
/// Spec: "The filename attribute must return the value it was initialized to."
pub fn get_filename(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";
    return internal.filename;
}

/// Getter for lineno
/// Spec: "The lineno attribute must return the value it was initialized to."
pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.lineno;
}

/// Getter for colno
/// Spec: "The colno attribute must return the value it was initialized to."
pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.colno;
}

/// Getter for error
/// Spec: "The error attribute must return the value it was initialized to.
///        It must initially be initialized to undefined."
/// Note: Returns a pointer or null, represented as an anyopaque pointer.
///       Null is represented by returning a special "undefined" marker pointer.
pub fn get_error(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse {
        // Return undefined
        return runtime.JSValue.jsUndefined;
    };
    // error is a stored V8 handle - use fromHandleNonOwning since lifecycle
    // is managed by ErrorEvent's InternalState
    if (internal.@"error") |err| {
        return runtime.JSValue.fromHandleNonOwning(@constCast(err));
    }
    return runtime.JSValue.jsUndefined;
}

/// Marker value for JavaScript "undefined"
/// This is a static address that can be checked by callers
const undefined_marker: u8 = 0;

// =============================================================================
// Factory functions for creating ErrorEvent instances
// =============================================================================

/// Create an ErrorEvent with the given attributes
/// This is used by the "report an exception" algorithm
pub fn createErrorEvent(
    _: std.mem.Allocator,
    ctx: runtime.Context,
    message: []const u8,
    filename: []const u8,
    lineno: u32,
    colno: u32,
    err: ?*const anyopaque,
    cancelable: bool,
) !*runtime.Instance {
    // Create ErrorEventInit dictionary
    const event_init = dictionaries.EventInit{
        .bubbles = false, // Error events don't bubble by default
        .cancelable = cancelable,
        .composed = false,
    };

    const error_init = dictionaries.ErrorEventInit{
        .base = event_init,
        .message = runtime.DOMString.initInterned(message),
        .filename = filename, // USVString is []const u8
        .lineno = lineno,
        .colno = colno,
        // error is a V8 handle passed in - use fromHandleNonOwning since caller retains ownership
        .@"error" = if (err) |e| runtime.JSValue.fromHandleNonOwning(@constCast(e)) else null,
    };

    // Construct the ErrorEvent
    return call_constructor(
        ctx,
        runtime.DOMString.initInterned("error"),
        .{ .was_passed = true, .value = error_init },
    );
}

/// Set the isTrusted flag on an ErrorEvent
/// Called when creating events via the "fire an event" algorithm
pub fn setIsTrusted(instance: *runtime.Instance, value: bool) void {
    const state = instance.getState(State);
    // isTrusted is in the base Event state, not ErrorEvent's own state
    state.base.own.isTrusted = value;
}
