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
const engine = @import("engine");
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#cqs-constructor
/// new CountQueuingStrategy(init)
///
/// Steps:
/// 1. Set this.[[highWaterMark]] to init["highWaterMark"]
pub fn call_constructor(ctx: runtime.Context, init_data: dictionaries.QueuingStrategyInit) !*runtime.Instance {
    // Create instance
    const instance = try init(ctx.allocator, State, &CountQueuingStrategy.vtable, ctx);
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
/// Spec: https://streams.spec.whatwg.org/#cqs-high-water-mark
/// readonly attribute unrestricted double highWaterMark
///
/// Steps:
/// 1. Return this.[[highWaterMark]]
pub fn get_highWaterMark(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    return internal.high_water_mark;
}

/// The count queuing strategy size function's steps (Streams 7.3.2, step
/// 1): "Return 1." Not a method: it does not look at `this`, or at its
/// argument.
fn countSizeSteps(data: ?*anyopaque, arguments: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
    _ = data;
    _ = arguments;
    return runtime.JSValue.fromNumber(1);
}

/// The steps of every realm's count queuing strategy size function. A
/// static: the functions read it on every call, for their realm's life.
const count_size_function: runtime.BuiltinFunction = .{ .steps = countSizeSteps, .data = null };

/// The global object's slot that keeps it (engine.globalBuiltinFunction).
const count_size_key = "crane:count queuing strategy size function";

/// Getter for size
///
/// Spec: https://streams.spec.whatwg.org/#cqs-size
/// readonly attribute Function size
///
/// 1. Return this's relevant global object's count queuing strategy size
///    function.
///
/// Every global object has one (7.3.2): 2. Let F be
/// ! CreateBuiltinFunction(steps, 0, "size", « », globalObject's relevant
/// Realm) - made on the first read in the realm, the same function after
/// (Blink's GetCachedSizeFunction). The result is a hold of it, which the
/// binding releases, as it does every JSValue a getter returns.
pub fn get_size(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const function = try engine.globalBuiltinFunction(instance.ctx, count_size_key, "size", 0, &count_size_function);
    return function.take();
}
