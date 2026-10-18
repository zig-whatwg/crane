//! WebIDL dictionary: CaretPositionFromPointOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CaretPositionFromPointOptions = struct {
    shadowRoots: ?[]const *runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "shadowRoots", .empty_sequence },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "shadowRoots", "ShadowRoot" },
    };
};
