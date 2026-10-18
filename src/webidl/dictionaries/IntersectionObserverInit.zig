//! WebIDL dictionary: IntersectionObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IntersectionObserverInit = struct {
    root: ?runtime.JSValue = null,
    rootMargin: ?runtime.DOMString = null,
    scrollMargin: ?runtime.DOMString = null,
    threshold: ?runtime.JSValue = null,
    delay: ?i32 = null,
    trackVisibility: ?bool = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"threshold"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "root", .null },
        .{ "rootMargin", .{ .string = "0px" } },
        .{ "scrollMargin", .{ .string = "0px" } },
        .{ "threshold", .{ .number = 0 } },
        .{ "delay", .{ .number = 0 } },
        .{ "trackVisibility", .{ .boolean = false } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"root"};
};
