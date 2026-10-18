//! WebIDL dictionary: CSSStyleSheetInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CSSStyleSheetInit = struct {
    baseURL: ?runtime.DOMString = null,
    media: ?runtime.JSValue = null,
    disabled: ?bool = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"media"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "baseURL", .null },
        .{ "media", .{ .string = "" } },
        .{ "disabled", .{ .boolean = false } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"baseURL"};
};
