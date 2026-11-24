//! WebIDL typedef: UnrestrictedDoubleOrDOMPointInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const UnrestrictedDoubleOrDOMPointInit = union(enum) {
    double: f64,
    dompoint_init: dictionaries.DOMPointInit,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "dompoint_init", .kind = .dictionary },
    };
};
