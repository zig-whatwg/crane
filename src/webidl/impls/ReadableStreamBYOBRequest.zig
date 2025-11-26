//! Implementation for ReadableStreamBYOBRequest interface
//!
//! Spec: https://streams.spec.whatwg.org/#rs-byob-request-class
//!
//! Represents a request to fill a user-provided buffer.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ReadableStreamBYOBRequest = interfaces.ReadableStreamBYOBRequest;

pub const State = ReadableStreamBYOBRequest.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
    BufferDetached, // From ReadableByteStreamController

    RangeError, // From ReadableByteStreamController
    NullValue, // From ReadableByteStreamController
    NoEventLoop,
};

/// Internal state for ReadableStreamBYOBRequest
///
/// Spec: § 4.8 "ReadableStreamBYOBRequest"
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[controller]]: The parent ReadableByteStreamController
    /// null if request has been responded to
    controller: ?*runtime.Instance,

    /// [[view]]: The ArrayBufferView to write into
    /// null if request has been responded to
    view: ?typedefs.ArrayBufferView,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // No dynamic allocations in this struct
    }
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    state.own._internal.?.* = .{
        .allocator = allocator,
        .controller = null,
        .view = null,
    };

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

// ============================================================================
// WebIDL Interface Methods
// ============================================================================

/// Getter for view
///
/// Spec: § 4.8.2 "The view getter steps are:"
pub fn get_view(instance: *runtime.Instance) ImplError!?typedefs.ArrayBufferView {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Return this.[[view]]
    // Per spec, returns null if the request has been responded to
    return internal.view;
}

/// Operation: respond
///
/// Spec: § 4.8.3 "The respond(bytesWritten) method steps are:"
pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If this.[[controller]] is undefined, throw TypeError
    const controller = internal.controller orelse return error.TypeError;

    // Step 2: If this.[[view]].[[ViewedArrayBuffer]] is detached, throw TypeError
    if (internal.view) |view| {
        if (view.isDetached()) {
            return error.TypeError;
        }
    }

    // Step 3: Assert ! IsDetachedBuffer(view.[[ViewedArrayBuffer]]) is false
    // (Validation happens in controller)

    // Step 4: Perform ? ReadableByteStreamControllerRespond(this.[[controller]], bytesWritten)
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    try ReadableByteStreamControllerImpl.respond(controller, bytesWritten);

    // Step 5: Mark as responded by clearing references
    internal.controller = null;
    internal.view = null;
}

/// Operation: respondWithNewView
///
/// Spec: § 4.8.3 "The respondWithNewView(view) method steps are:"
pub fn call_respondWithNewView(instance: *runtime.Instance, view: typedefs.ArrayBufferView) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If this.[[controller]] is undefined, throw TypeError
    const controller = internal.controller orelse return error.TypeError;

    // Step 2: If ! IsDetachedBuffer(view.[[ViewedArrayBuffer]]) is true, throw TypeError
    // TODO: Implement IsDetachedBuffer check when ArrayBufferView type is fully supported
    // Currently skipping this validation step

    // Step 3: Return ? ReadableByteStreamControllerRespondWithNewView(this.[[controller]], view)
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    try ReadableByteStreamControllerImpl.respondWithNewView(controller, view);

    // Step 4: Mark as responded by clearing references
    internal.controller = null;
    internal.view = null;
}

// ============================================================================
// Internal Helper Functions (Used by ReadableByteStreamController)
// ============================================================================

/// Create a new BYOB request
///
/// Called by ReadableByteStreamController when creating a BYOB request
pub fn create(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    controller: *runtime.Instance,
    view: typedefs.ArrayBufferView,
) !*runtime.Instance {
    const instance = try init(allocator, State, &ReadableStreamBYOBRequest.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    internal.controller = controller;
    internal.view = view;

    return instance;
}

/// Invalidate the request (clear controller and view references)
///
/// Called by ReadableByteStreamController when invalidating the BYOB request
pub fn invalidate(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    internal.controller = null;
    internal.view = null;
}
