//! ByteLengthQueuingStrategy Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#blqs-class
//!
//! A queuing strategy that uses byte length for backpressure.
//! This is a simple value object that stores the high water mark.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ByteLengthQueuingStrategy = interfaces.ByteLengthQueuingStrategy;

pub const State = ByteLengthQueuingStrategy.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for ByteLengthQueuingStrategy
///
/// Per WHATWG Streams spec § 7.1 (ByteLengthQueuingStrategy class)
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#blqs-constructor
/// new ByteLengthQueuingStrategy(init)
///
/// Steps:
/// 1. Set this.[[highWaterMark]] to init["highWaterMark"]
pub fn call_constructor(ctx: runtime.Context, init_data: dictionaries.QueuingStrategyInit) !*runtime.Instance {
    // Create instance
    const instance = try init(ctx.allocator, State, &ByteLengthQueuingStrategy.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    internal.* = InternalState{
        .high_water_mark = init_data.highWaterMark,
        .allocator = ctx.allocator,
    };

    state.own._internal = internal;

    return instance;
}

/// Getter for highWaterMark
///
/// Spec: https://streams.spec.whatwg.org/#blqs-high-water-mark
/// readonly attribute unrestricted double highWaterMark
///
/// Steps:
/// 1. Return this.[[highWaterMark]]
pub fn get_highWaterMark(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    return internal.high_water_mark;
}

/// Byte length size function
///
/// This is the function returned by the size getter.
/// Per spec, it extracts the "byteLength" property from the chunk.
///
/// Spec: https://streams.spec.whatwg.org/#byte-length-queuing-strategy-size-function
/// Steps (given chunk):
/// 1. Return ? GetV(chunk, "byteLength").
fn byteLengthSizeFunction(arguments: []const runtime.JSValue) runtime.JSValue {
    _ = arguments;
    // TODO: Extract byteLength property from chunk
    // This requires JS runtime integration
    // For now, return undefined
    return runtime.JSValue.jsUndefined;
}

/// Getter for size
///
/// Spec: https://streams.spec.whatwg.org/#blqs-size
/// readonly attribute Function size
///
/// The size getter steps are:
/// 1. Return this's relevant global object's byte length queuing strategy size function.
///
/// Note: This returns a Function object. The actual size calculation happens
/// when the function is called with a chunk.
pub fn get_size(instance: *runtime.Instance) anyerror!callbacks.Function {
    _ = instance;

    // Return the byte length size function as an opaque pointer.
    // callbacks.Function is *anyopaque for FFI compatibility.
    // In a full implementation, this would be a global function cached per realm.
    return @ptrCast(@constCast(&byteLengthSizeFunction));
}
