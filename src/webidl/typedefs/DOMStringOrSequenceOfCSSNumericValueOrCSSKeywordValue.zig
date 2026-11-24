//! WebIDL typedef: DOMStringOrSequenceOfCSSNumericValueOrCSSKeywordValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrSequenceOfCSSNumericValueOrCSSKeywordValue = union(enum) {
    domstring: runtime.DOMString,
    cssnumeric_value_or_csskeyword_value_sequence: []const typedefs.CSSNumericValueOrCSSKeywordValue,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "cssnumeric_value_or_csskeyword_value_sequence", .kind = .{ .sequence = null } },
    };
};
