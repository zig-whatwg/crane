//! WebIDL dictionary: IntersectionObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const IntersectionObserverInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    root: ?typedefs.ElementOrDocument = null,
    rootMargin: ?runtime.DOMString = null,
    scrollMargin: ?runtime.DOMString = null,
    threshold: ?typedefs.DoubleOrSequenceOfDouble = null,
    delay: ?i32 = null,
    trackVisibility: ?bool = null,

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
