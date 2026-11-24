//! WebIDL typedef: CSSStyleValueOrUSVString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const CSSStyleValueOrUSVString = union(enum) {
    cssstyle_value: *runtime.Instance,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "cssstyle_value", .kind = .{ .interface = "CSSStyleValue" } },
        .{ .field = "usvstring", .kind = .string },
    };
};
