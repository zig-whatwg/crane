//! WebIDL dictionary: StreamPipeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const StreamPipeOptions = struct {
    preventClose: ?bool = null,
    preventAbort: ?bool = null,
    preventCancel: ?bool = null,
    signal: ?*runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "preventClose", .{ .boolean = false } },
        .{ "preventAbort", .{ .boolean = false } },
        .{ "preventCancel", .{ .boolean = false } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
