//! WebIDL dictionary: LockOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LockOptions = struct {
    mode: ?enums.LockMode = null,
    ifAvailable: ?bool = null,
    steal: ?bool = null,
    signal: ?*runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mode", .{ .string = "exclusive" } },
        .{ "ifAvailable", .{ .boolean = false } },
        .{ "steal", .{ .boolean = false } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
