//! WebIDL dictionary: ViewTimelineOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const ViewTimelineOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    subject: ?*runtime.Instance = null,
    axis: ?enums.ScrollAxis = null,
    inset: ?typedefs.DOMStringOrSequenceOfCSSNumericValueOrCSSKeywordValue = null,

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
