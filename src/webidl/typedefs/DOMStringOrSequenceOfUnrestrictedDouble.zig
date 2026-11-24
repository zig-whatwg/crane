//! WebIDL typedef: DOMStringOrSequenceOfUnrestrictedDouble
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrSequenceOfUnrestrictedDouble = union(enum) {
    domstring: runtime.DOMString,
    double_sequence: []const f64,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "double_sequence", .kind = .{ .sequence = null } },
    };
};
