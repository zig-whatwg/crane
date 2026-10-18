//! WebIDL dictionary: ViewTimelineOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ViewTimelineOptions = struct {
    subject: ?*runtime.Instance = null,
    axis: ?enums.ScrollAxis = null,
    inset: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"inset"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "axis", .{ .string = "block" } },
        .{ "inset", .{ .string = "auto" } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "subject", "Element" },
    };
};
