//! WebIDL typedef: BooleanOrUnrestrictedDoubleOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const BooleanOrUnrestrictedDoubleOrDOMString = union(enum) {
    boolean: bool,
    double: f64,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "double", .kind = .numeric },
        .{ .field = "domstring", .kind = .string },
    };
};
