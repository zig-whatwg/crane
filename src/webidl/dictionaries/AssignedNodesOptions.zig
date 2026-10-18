//! WebIDL dictionary: AssignedNodesOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AssignedNodesOptions = struct {
    flatten: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "flatten", .{ .boolean = false } },
    };
};
