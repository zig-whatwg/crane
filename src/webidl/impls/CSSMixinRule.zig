//! Implementation for CSSMixinRule interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const CSSMixinRule = interfaces.CSSMixinRule;

pub const State = CSSMixinRule.State;

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

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for contents
pub fn get_contents(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getParameters
pub fn call_getParameters(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
