//! Implementation for GeolocationPosition interface
//! Spec: https://www.w3.org/TR/geolocation/#position_interface (specs/w3c/geolocation.md §8)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const GeolocationPosition = interfaces.GeolocationPosition;

pub const State = GeolocationPosition.State;
pub const construction_args = .{ "coords", "timestamp", "is_high_accuracy" };

pub const ImplError = error{
    InvalidStateError,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    coords: *runtime.Instance,
    timestamp: typedefs.EpochTimeStamp,
    /// §8.4 [[isHighAccuracy]] internal slot.
    is_high_accuracy: bool,
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    const coords: *runtime.Instance = if (comptime @hasField(@TypeOf(args), "coords"))
        args.coords
    else
        try interfaces.GeolocationCoordinates.init(allocator, instance.ctx);

    const timestamp: typedefs.EpochTimeStamp = if (comptime @hasField(@TypeOf(args), "timestamp"))
        args.timestamp
    else
        0;

    const is_high_accuracy: bool = if (comptime @hasField(@TypeOf(args), "is_high_accuracy"))
        args.is_high_accuracy
    else
        false;

    internal.* = .{
        .allocator = allocator,
        .coords = coords,
        .timestamp = timestamp,
        .is_high_accuracy = is_high_accuracy,
    };
    instance.getState(StateType).own._internal = internal;
    // Tie coords's wrapper lifetime to this GeolocationPosition wrapper.
    dom.same_object_cache.made(instance, coords, "coords");
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    dom.same_object_cache.forget(instance, "coords");
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn getInternal(instance: *runtime.Instance) ImplError!*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

/// Getter for coords (§8.1)
pub fn get_coords(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try getInternal(instance)).coords;
}

/// Getter for timestamp (§8.2)
pub fn get_timestamp(instance: *runtime.Instance) anyerror!typedefs.EpochTimeStamp {
    return (try getInternal(instance)).timestamp;
}

/// Operation: toJSON (§8.3, [Default] object toJSON())
pub fn call_toJSON(instance: *runtime.Instance) anyerror!GeolocationPosition.GeolocationPositionToJSON {
    const internal = try getInternal(instance);
    return .{
        .coords = internal.coords,
        .timestamp = internal.timestamp,
    };
}
