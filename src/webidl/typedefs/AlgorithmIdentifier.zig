//! WebIDL typedef: AlgorithmIdentifier
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const AlgorithmIdentifier = union(enum) {
    object: runtime.JSValue,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "object", .kind = .object },
        .{ .field = "domstring", .kind = .string },
    };
};
