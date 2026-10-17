//! Implementation for PerformanceContainerTiming interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const PerformanceContainerTiming = interfaces.PerformanceContainerTiming;

pub const State = PerformanceContainerTiming.State;

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

/// Getter for identifier
pub fn get_identifier(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for intersectionRect
pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for size
pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for firstRenderTime
pub fn get_firstRenderTime(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastPaintedElement
pub fn get_lastPaintedElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for rootElement
pub fn get_rootElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
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

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceContainerTiming.PerformanceContainerTimingToJSON {
    _ = instance;
    // TODO: Populate ToJSON struct from instance state
    return error.NotImplemented;
}
