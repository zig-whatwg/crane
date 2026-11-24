//! WebIDL typedef: CSSKeywordish
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const CSSKeywordish = union(enum) {
    domstring: runtime.DOMString,
    csskeyword_value: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "csskeyword_value", .kind = .{ .interface = "CSSKeywordValue" } },
    };
};
