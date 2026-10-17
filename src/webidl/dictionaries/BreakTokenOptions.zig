//! WebIDL dictionary: BreakTokenOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BreakTokenOptions = struct {
    childBreakTokens: ?[]const *runtime.Instance = null,
    data: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"data"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "childBreakTokens", "ChildBreakToken" },
    };
};
