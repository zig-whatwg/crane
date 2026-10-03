//! Implementation for QuotaExceededError interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const QuotaExceededError = interfaces.QuotaExceededError;

pub const State = QuotaExceededError.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.DOMException.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.DOMException.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context, message: webidl.Opt(runtime.DOMString), options: webidl.Opt(dictionaries.QuotaExceededErrorOptions)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &QuotaExceededError.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    // WebIDL §2.8.3 steps 1-2: the owning DOMException initializes its base.
    try @import("dom").dom_exceptions.initialize(instance, "QuotaExceededError", if (message.was_passed) message.value.asSlice() else "");
    const state = instance.getState(State);
    const values: dictionaries.QuotaExceededErrorOptions = if (options.was_passed) options.value else .{};
    // Step 3: optional quota, initially null.
    if (values.quota) |quota| {
        if (quota < 0) return error.RangeError;
        state.own.quota = quota;
    }
    // Step 4: optional requested amount, initially null.
    if (values.requested) |requested| {
        if (requested < 0) return error.RangeError;
        state.own.requested = requested;
    }
    // Step 5: a request cannot be smaller than the quota that it exceeded.
    if (state.own.quota) |quota| if (state.own.requested) |requested| {
        if (requested < quota) return error.RangeError;
    };
    return instance;
}

/// Getter for quota
pub fn get_quota(instance: *runtime.Instance) anyerror!?f64 {
    return instance.getState(State).own.quota;
}

/// Getter for requested
pub fn get_requested(instance: *runtime.Instance) anyerror!?f64 {
    return instance.getState(State).own.requested;
}
