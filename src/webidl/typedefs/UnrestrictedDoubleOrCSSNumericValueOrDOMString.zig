//! WebIDL typedef: UnrestrictedDoubleOrCSSNumericValueOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const UnrestrictedDoubleOrCSSNumericValueOrDOMString = union(enum) {
    double: f64,
    cssnumeric_value: *runtime.Instance,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "cssnumeric_value", .kind = .{ .interface = "CSSNumericValue" } },
        .{ .field = "domstring", .kind = .string },
    };
};
