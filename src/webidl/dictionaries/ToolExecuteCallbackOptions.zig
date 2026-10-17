//! WebIDL dictionary: ToolExecuteCallbackOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ToolExecuteCallbackOptions = struct {
    signal: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
