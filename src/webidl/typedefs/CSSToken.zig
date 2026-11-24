//! WebIDL typedef: CSSToken
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const CSSToken = union(enum) {
    domstring: runtime.DOMString,
    cssstyle_value: *runtime.Instance,
    cssparser_value: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "cssstyle_value", .kind = .{ .interface = "CSSStyleValue" } },
        .{ .field = "cssparser_value", .kind = .{ .interface = "CSSParserValue" } },
    };
};
