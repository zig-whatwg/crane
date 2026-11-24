//! WebIDL typedef: MLNumber
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const MLNumber = union(enum) {
    bigint: runtime.JSValue,
    double: f64,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "bigint", .kind = .bigint },
        .{ .field = "double", .kind = .numeric },
    };
};
