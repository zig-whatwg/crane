//! Implementation for GeolocationPositionError interface
//! Spec: https://www.w3.org/TR/geolocation/#position_error_interface (specs/w3c/geolocation.md §10)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const GeolocationPositionError = interfaces.GeolocationPositionError;

pub const State = GeolocationPositionError.State;
pub const construction_args = .{ "code", "message" };

pub const ImplError = error{
    InvalidStateError,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    code: u16,
    /// Static/interned developer-friendly English description (§10.3).
    message: []const u8,
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    const code: u16 = if (comptime @hasField(@TypeOf(args), "code"))
        args.code
    else
        GeolocationPositionError.get_POSITION_UNAVAILABLE();

    const message: []const u8 = if (comptime @hasField(@TypeOf(args), "message"))
        args.message
    else switch (code) {
        1 => "User denied Geolocation",
        2 => "Position unavailable",
        3 => "Timeout expired",
        else => "",
    };

    internal.* = .{
        .allocator = allocator,
        .code = code,
        .message = message,
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

/// Getter for code (§10.2)
pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
    return (try getInternal(instance)).code;
}

/// Getter for message (§10.3)
pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try getInternal(instance);
    return runtime.DOMString.initInterned(internal.message);
}
