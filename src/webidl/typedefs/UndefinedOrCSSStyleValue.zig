//! WebIDL typedef: UndefinedOrCSSStyleValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const UndefinedOrCSSStyleValue = union(enum) {
    undefined: void,
    cssstyle_value: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "undefined", .kind = .undefined },
        .{ .field = "cssstyle_value", .kind = .{ .interface = "CSSStyleValue" } },
    };
};
