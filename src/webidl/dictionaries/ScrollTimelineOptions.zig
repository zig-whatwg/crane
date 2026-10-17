//! WebIDL dictionary: ScrollTimelineOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ScrollTimelineOptions = struct {
    source: ?*runtime.Instance = null,
    axis: ?enums.ScrollAxis = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"source"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "source", "Element" },
    };
};
