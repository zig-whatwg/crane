//! Implementation for LanguageModelParams interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const LanguageModelParams = interfaces.LanguageModelParams;

pub const State = LanguageModelParams.State;

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

/// Getter for defaultTopK
pub fn get_defaultTopK(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maxTopK
pub fn get_maxTopK(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defaultTemperature
pub fn get_defaultTemperature(instance: *runtime.Instance) anyerror!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maxTemperature
pub fn get_maxTemperature(instance: *runtime.Instance) anyerror!f32 {
    _ = instance;
    return error.NotImplemented;
}
