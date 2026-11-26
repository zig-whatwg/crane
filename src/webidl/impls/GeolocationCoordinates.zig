//! Implementation for GeolocationCoordinates interface
//! Spec: https://www.w3.org/TR/geolocation/#coordinates_interface (specs/w3c/geolocation.md §9)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html_core = @import("html_core");
const GeolocationCoordinates = interfaces.GeolocationCoordinates;

pub const State = GeolocationCoordinates.State;
pub const Coordinates = html_core.window.host_overrides.GeolocationCoordinates;
pub const construction_args = .{"coordinates"};

pub const ImplError = error{
    InvalidStateError,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    latitude: f64,
    longitude: f64,
    accuracy: f64,
    altitude: ?f64,
    altitude_accuracy: ?f64,
    heading: ?f64,
    speed: ?f64,
};

fn sanitizeOptionalDouble(value: ?f64) ?f64 {
    const v = value orelse return null;
    if (std.math.isNan(v)) return null;
    return v;
}

/// Initialize own state from `coordinates` construction argument.
/// Enforces W3C Geolocation §6.6 / §9.3 (commit 9d5829e): heading is null when
/// not available or when the device is stationary (speed == 0).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    const coords: Coordinates = if (comptime @hasField(@TypeOf(args), "coordinates"))
        args.coordinates
    else
        .{ .latitude = 0, .longitude = 0, .accuracy = 0 };

    const speed = sanitizeOptionalDouble(coords.speed);
    // W3C Geolocation §6.6 "heading": "null if not available or the device is stationary".
    const heading: ?f64 = if (speed != null and speed.? == 0.0) null else sanitizeOptionalDouble(coords.heading);

    internal.* = .{
        .allocator = allocator,
        .latitude = coords.latitude,
        .longitude = coords.longitude,
        .accuracy = coords.accuracy,
        .altitude = sanitizeOptionalDouble(coords.altitude),
        .altitude_accuracy = sanitizeOptionalDouble(coords.altitude_accuracy),
        .heading = heading,
        .speed = speed,
    };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn getInternal(instance: *runtime.Instance) ImplError!*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

/// Getter for accuracy (§9.1)
pub fn get_accuracy(instance: *runtime.Instance) anyerror!f64 {
    return (try getInternal(instance)).accuracy;
}

/// Getter for latitude (§9.1)
pub fn get_latitude(instance: *runtime.Instance) anyerror!f64 {
    return (try getInternal(instance)).latitude;
}

/// Getter for longitude (§9.1)
pub fn get_longitude(instance: *runtime.Instance) anyerror!f64 {
    return (try getInternal(instance)).longitude;
}

/// Getter for altitude (§9.2)
pub fn get_altitude(instance: *runtime.Instance) anyerror!?f64 {
    return (try getInternal(instance)).altitude;
}

/// Getter for altitudeAccuracy (§9.2)
pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyerror!?f64 {
    return (try getInternal(instance)).altitude_accuracy;
}

/// Getter for heading (§9.3)
pub fn get_heading(instance: *runtime.Instance) anyerror!?f64 {
    return (try getInternal(instance)).heading;
}

/// Getter for speed (§9.4)
pub fn get_speed(instance: *runtime.Instance) anyerror!?f64 {
    return (try getInternal(instance)).speed;
}

/// Operation: toJSON (§9.5, [Default] object toJSON())
pub fn call_toJSON(instance: *runtime.Instance) anyerror!GeolocationCoordinates.GeolocationCoordinatesToJSON {
    const internal = try getInternal(instance);
    return .{
        .accuracy = internal.accuracy,
        .latitude = internal.latitude,
        .longitude = internal.longitude,
        .altitude = internal.altitude,
        .altitudeAccuracy = internal.altitude_accuracy,
        .heading = internal.heading,
        .speed = internal.speed,
    };
}
