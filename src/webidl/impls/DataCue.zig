//! Implementation for DataCue interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DataCue = interfaces.DataCue;

pub const State = DataCue.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// DataCue (WICG DataCue): a TextTrackCue, made through the generated
/// construction chain so TextTrackCue's and EventTarget's state are there.
pub fn call_constructor(instance: *runtime.Instance, startTime: f64, endTime: f64, value: runtime.JSValue, @"type": webidl.Opt(runtime.DOMString)) !void {
    // The generated constructor made `instance` (WebIDL 3.7.1 step 1.8)
    // and frees it whole when a step fails (lane ctor1).
    // As VTTCue() steps 2-3: an end time of negative Infinity or NaN is a
    // TypeError.
    if (std.math.isNan(endTime) or endTime == -std.math.inf(f64)) return error.TypeError;
    _ = value;
    _ = @"type";
    // TODO(datacue): the value and type members (WICG DataCue) - not in the
    // 0.1 worklist (unratified).
    interfaces.TextTrackCue.set_startTime(instance, startTime) catch unreachable;
    interfaces.TextTrackCue.set_endTime(instance, endTime) catch unreachable;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
