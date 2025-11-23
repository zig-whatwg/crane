//! Implementation for WritableStreamDefaultController interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WritableStreamDefaultController = interfaces.WritableStreamDefaultController;

pub const State = WritableStreamDefaultController.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for WritableStreamDefaultController
pub const InternalState = struct {
    /// [[stream]]: WritableStream instance this controller controls
    stream: ?*runtime.Instance,

    /// [[writeAlgorithm]]: Underlying sink write callback
    write_algorithm: ?*const anyopaque,

    /// [[closeAlgorithm]]: Underlying sink close callback
    close_algorithm: ?*const anyopaque,

    /// [[abortAlgorithm]]: Underlying sink abort callback
    abort_algorithm: ?*const anyopaque,

    /// [[strategyHWM]]: High water mark for backpressure
    strategy_hwm: f64,

    /// [[strategySizeAlgorithm]]: Function to compute chunk size
    strategy_size_algorithm: ?*const anyopaque,

    /// [[started]]: Whether start algorithm has completed
    started: bool,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // InternalState is set up by SetUpWritableStreamDefaultController
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
    }
    runtime.Instance.deinit(instance);
}

/// Getter for signal
pub fn get_signal(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) ImplError!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}
