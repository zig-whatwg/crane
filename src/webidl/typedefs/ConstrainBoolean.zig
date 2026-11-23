//! WebIDL typedef: ConstrainBoolean
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const ConstrainBoolean = union(enum) {
    boolean: bool,
    constrain_boolean_parameters: dictionaries.ConstrainBooleanParameters,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "constrain_boolean_parameters", .kind = .dictionary },
    };
};
