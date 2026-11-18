//! Implementation for PerformanceTimingConfidence interface
//!
//! Navigation Timing 3.3.2: how far a navigation entry's metrics represent
//! the user's device - a randomized trigger rate and a value, "set once, and
//! not change for the lifetime" of the entry. Made by the
//! PerformanceNavigationTiming confidence getter (its steps 3-5), which gives
//! both values at construction.
//!
//! Spec: https://w3c.github.io/navigation-timing/#sec-performance-timing-confidence

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const enums = @import("enums");
const PerformanceTimingConfidence = interfaces.PerformanceTimingConfidence;

pub const State = PerformanceTimingConfidence.State;

pub const ImplError = error{
    NotImplemented,
};

/// The randomized trigger rate (f64) and the value
/// (enums.PerformanceTimingConfidenceValue), given by the confidence getter.
pub const construction_args = .{ "randomized_trigger_rate", "value" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// "confidence's randomizedTriggerRate" (getter step 4).
    randomized_trigger_rate: f64,
    /// "confidence's value" (getter step 5).
    value: enums.PerformanceTimingConfidenceValue,
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
        .randomized_trigger_rate = if (@hasField(@TypeOf(args), "randomized_trigger_rate")) args.randomized_trigger_rate else 0,
        .value = if (@hasField(@TypeOf(args), "value")) args.value else ._high_,
    };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

/// Getter for randomizedTriggerRate: "a real number in the interval [0, 1),
/// indicating how often noise is applied when exposing the confidence value".
pub fn get_randomizedTriggerRate(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).randomized_trigger_rate;
}

/// Getter for value.
pub fn get_value(instance: *runtime.Instance) anyerror!enums.PerformanceTimingConfidenceValue {
    return (try internalOf(instance)).value;
}

/// Operation: toJSON - "runs the default toJSON steps for this" (WebIDL
/// 3.7.4.1): an ordinary object of the current realm with a data property for
/// each attribute, in interface order: randomizedTriggerRate, then value.
/// The IDL declares the operation without [Default], so the binding hands
/// back the object made here (OWNED).
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    const realm = engine.currentRealm() orelse instance.ctx;
    const value_name: []const u8 = switch (internal.value) {
        ._high_ => "high",
        ._low_ => "low",
    };
    const object = try engine.createDictionaryObject(realm, &.{
        .{ .name = "randomizedTriggerRate", .value = runtime.JSValue.fromNumber(internal.randomized_trigger_rate) },
        .{ .name = "value", .value = runtime.JSValue.fromStringRef(value_name) },
    });
    return object.take();
}
