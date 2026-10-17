//! Implementation for ModelContext interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const ModelContext = interfaces.ModelContext;

pub const State = ModelContext.State;

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

/// Operation: getTools
pub fn call_getTools(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ModelContextGetToolOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: registerTool
pub fn call_registerTool(instance: *runtime.Instance, tool: dictionaries.ModelContextTool, options: webidl.Opt(dictionaries.ModelContextRegisterToolOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = tool;
    _ = options;
    return error.NotImplemented;
}

/// Operation: executeTool
pub fn call_executeTool(instance: *runtime.Instance, tool: dictionaries.RegisteredTool, inputObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(dictionaries.ModelContextExecuteToolOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = tool;
    _ = inputObject;
    _ = options;
    return error.NotImplemented;
}
