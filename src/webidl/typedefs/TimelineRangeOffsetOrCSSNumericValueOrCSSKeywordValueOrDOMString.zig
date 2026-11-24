//! WebIDL typedef: TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = union(enum) {
    timeline_range_offset: dictionaries.TimelineRangeOffset,
    cssnumeric_value: *runtime.Instance,
    csskeyword_value: *runtime.Instance,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "timeline_range_offset", .kind = .dictionary },
        .{ .field = "cssnumeric_value", .kind = .{ .interface = "CSSNumericValue" } },
        .{ .field = "csskeyword_value", .kind = .{ .interface = "CSSKeywordValue" } },
        .{ .field = "domstring", .kind = .string },
    };
};
