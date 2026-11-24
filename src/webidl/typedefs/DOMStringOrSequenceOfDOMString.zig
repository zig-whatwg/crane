//! WebIDL typedef: DOMStringOrSequenceOfDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrSequenceOfDOMString = union(enum) {
    domstring: runtime.DOMString,
    domstring_sequence: []const runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "domstring_sequence", .kind = .{ .sequence = null } },
    };
};
