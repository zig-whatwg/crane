//! WebIDL typedef: ConstrainBooleanOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const ConstrainBooleanOrDOMString = union(enum) {
    boolean: bool,
    domstring: runtime.DOMString,
    constrain_boolean_or_domstring_parameters: dictionaries.ConstrainBooleanOrDOMStringParameters,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "domstring", .kind = .string },
        .{ .field = "constrain_boolean_or_domstring_parameters", .kind = .dictionary },
    };
};
