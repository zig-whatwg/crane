//! WebIDL dictionary: BasePropertyIndexedKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const BasePropertyIndexedKeyframe = struct {
    offset: ?runtime.JSValue = null,
    easing: ?runtime.JSValue = null,
    composite: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "easing", "composite" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "offset", .empty_sequence },
        .{ "easing", .empty_sequence },
        .{ "composite", .empty_sequence },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"offset"};
};
