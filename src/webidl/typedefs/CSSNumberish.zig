//! WebIDL typedef: CSSNumberish
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const CSSNumberish = union(enum) {
    double: f64,
    cssnumeric_value: *runtime.Instance,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{"double"};

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "cssnumeric_value", .kind = .{ .interface = "CSSNumericValue" } },
    };
};
