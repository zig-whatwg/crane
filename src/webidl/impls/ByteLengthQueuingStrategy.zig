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
const engine = @import("engine");
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

/// The byte length queuing strategy size function's steps (Streams 7.2.2,
/// step 1), given `chunk`: "Return ? GetV(chunk, "byteLength")." Not a
/// method: it does not look at `this`.
///
/// GetV(V, P): 1. Let O be ? ToObject(V) - undefined and null throw a
/// TypeError. 2. Return ? O.[[Get]](P, V). An object is read with Get. A
/// primitive's ToObject wrapper has no own "byteLength", so its [[Get]] reads
/// its prototype chain; the protocol's Get takes an object, so a primitive
/// answers undefined. Deviation, stated: they differ only when script gives
/// a primitive's prototype (String.prototype, Number.prototype, ...) a
/// "byteLength" - the WPT reads `size('potato')` as undefined, which both do.
fn byteLengthSizeSteps(data: ?*anyopaque, arguments: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
    _ = data;
    const chunk: runtime.JSValue = if (arguments.len > 0) arguments[0] else .undefined;
    const realm = engine.currentRealm() orelse return error.OperationFailed;
    switch (engine.typeOf(realm, chunk)) {
        // ToObject(undefined or null) throws a TypeError.
        .undefined, .null => return error.TypeError,
        .object => {
            const value = engine.getProperty(realm, chunk, "byteLength") catch |err| return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.TypeError => error.TypeError,
                error.ExceptionPending => error.ExceptionPending,
                error.NotSupported => error.NotSupported,
                error.DataCloneError => error.DataCloneError,
                error.OperationFailed, error.ExceptionReported, error.MutedScriptError => error.OperationFailed,
            };
            // The result is the engine's to release (engine.BuiltinSteps).
            return value.take();
        },
        .boolean, .string, .symbol, .number, .bigint => return .undefined,
    }
}

/// The steps of every realm's byte length queuing strategy size function. A
/// static: the functions read it on every call, for their realm's life.
const byte_length_size_function: runtime.BuiltinFunction = .{ .steps = byteLengthSizeSteps, .data = null };

/// The global object's slot that keeps it (engine.globalBuiltinFunction).
const byte_length_size_key = "crane:byte length queuing strategy size function";

/// Getter for size
///
/// Spec: https://streams.spec.whatwg.org/#blqs-size
/// readonly attribute Function size
///
/// 1. Return this's relevant global object's byte length queuing strategy
///    size function.
///
/// Every global object has one (7.2.2): 2. Let F be
/// ! CreateBuiltinFunction(steps, 1, "size", « », globalObject's relevant
/// Realm) - made on the first read in the realm, the same function after
/// (Blink's GetCachedSizeFunction). The result is a hold of it, which the
/// binding releases, as it does every JSValue a getter returns.
pub fn get_size(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const function = try engine.globalBuiltinFunction(instance.ctx, byte_length_size_key, "size", 1, &byte_length_size_function);
    return function.take();
}
