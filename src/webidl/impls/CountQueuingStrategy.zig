//! CountQueuingStrategy Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#cqs-class
//!
//! A queuing strategy that counts chunks for backpressure (size always = 1).
//! This is a simple value object that stores the high water mark.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CountQueuingStrategy = interfaces.CountQueuingStrategy;

pub const State = CountQueuingStrategy.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for CountQueuingStrategy
///
/// Per WHATWG Streams spec § 7.2 (CountQueuingStrategy class)
/// This class has a single internal slot: [[highWaterMark]]
pub const InternalState = struct {
    /// [[highWaterMark]]: The high water mark value
    high_water_mark: f64,

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
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#cqs-constructor
/// new CountQueuingStrategy(init)
///
/// Steps:
/// 1. Set this.[[highWaterMark]] to init["highWaterMark"]
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    init_data: dictionaries.QueuingStrategyInit,
) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &CountQueuingStrategy.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .high_water_mark = init_data.highWaterMark,
        .allocator = allocator,
    };

    state.own._internal = internal;

    return instance;
}

/// Getter for highWaterMark
///
/// Spec: https://streams.spec.whatwg.org/#cqs-high-water-mark
/// readonly attribute unrestricted double highWaterMark
///
/// Steps:
/// 1. Return this.[[highWaterMark]]
pub fn get_highWaterMark(instance: *runtime.Instance) !f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    return internal.high_water_mark;
}

/// Count size function
///
/// This is the function returned by the size getter.
/// Per spec, it always returns 1 (count-based strategy).
///
/// Spec: https://streams.spec.whatwg.org/#count-queuing-strategy-size-function
/// Steps (given chunk):
/// 1. Return 1.
fn countSizeFunction(arguments: *const anyopaque) *const anyopaque {
    _ = arguments;
    // Count strategy always returns 1 per chunk
    // Return as opaque pointer (in real impl, would be JS Number object)
    return @ptrFromInt(1);
}

/// Getter for size
///
/// Spec: https://streams.spec.whatwg.org/#cqs-size
/// readonly attribute Function size
///
/// The size getter steps are:
/// 1. Return this's relevant global object's count queuing strategy size function.
///
/// Note: This returns a Function object that always returns 1.
pub fn get_size(instance: *runtime.Instance) !callbacks.Function {
    _ = instance;

    // Return the count size function
    // In a full implementation, this would be a global function cached per realm
    return &countSizeFunction;
}
