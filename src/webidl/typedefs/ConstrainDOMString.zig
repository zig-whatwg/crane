//! WebIDL typedef: ConstrainDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const ConstrainDOMString = union(enum) {
    domstring: runtime.DOMString,
    domstring_sequence: []const runtime.DOMString,
    constrain_domstring_parameters: dictionaries.ConstrainDOMStringParameters,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "domstring_sequence", .kind = .sequence },
        .{ .field = "constrain_domstring_parameters", .kind = .dictionary },
    };
};
