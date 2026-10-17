//! Implementation for MediaStreamTrackVideoStats interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const MediaStreamTrackVideoStats = interfaces.MediaStreamTrackVideoStats;

pub const State = MediaStreamTrackVideoStats.State;

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

/// Getter for deliveredFrames
pub fn get_deliveredFrames(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for discardedFrames
pub fn get_discardedFrames(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for totalFrames
pub fn get_totalFrames(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.MediaStreamTrackVideoStats.MediaStreamTrackVideoStatsToJSON {
    _ = instance;
    // TODO: Populate ToJSON struct from instance state
    return error.NotImplemented;
}
