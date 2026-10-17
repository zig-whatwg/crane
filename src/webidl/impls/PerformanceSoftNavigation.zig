//! Implementation for PerformanceSoftNavigation interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const PerformanceSoftNavigation = interfaces.PerformanceSoftNavigation;

pub const State = PerformanceSoftNavigation.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

// Construction and destruction: the generated interface's chain runs the
// parent interface's steps. For state of this interface's own, define
//
//   pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void
//   pub fn deinitOwn(instance: *runtime.Instance) void
//
// (run after and before the parent's), and list what it is given at
// construction in `pub const construction_args = .{"name"};`.

/// Getter for navigationType
pub fn get_navigationType(instance: *runtime.Instance) anyerror!enums.NavigationType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for interactionId
pub fn get_interactionId(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for paintTime
pub fn get_paintTime(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for presentationTime
pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?typedefs.DOMHighResTimeStamp {
    _ = instance;
    return null;
}

/// Operation: getLargestInteractionContentfulPaint
pub fn call_getLargestInteractionContentfulPaint(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceSoftNavigation.PerformanceSoftNavigationToJSON {
    _ = instance;
    // TODO: Populate ToJSON struct from instance state
    return error.NotImplemented;
}
