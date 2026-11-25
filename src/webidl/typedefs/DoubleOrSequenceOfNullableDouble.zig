//! WebIDL typedef: DoubleOrSequenceOfNullableDouble
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DoubleOrSequenceOfNullableDouble = union(enum) {
    double: f64,
    double_sequence: []const ?f64,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{ "double", "double_sequence" };

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "double_sequence", .kind = .{ .sequence = null } },
    };
};
