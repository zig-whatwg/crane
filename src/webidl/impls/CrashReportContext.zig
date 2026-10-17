//! Implementation for CrashReportContext interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const CrashReportContext = interfaces.CrashReportContext;

pub const State = CrashReportContext.State;

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

/// Operation: set
pub fn call_set(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = key;
    _ = value;
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, key: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: initialize
pub fn call_initialize(instance: *runtime.Instance, length: u64) anyerror!runtime.JSValue {
    _ = instance;
    _ = length;
    return error.NotImplemented;
}
