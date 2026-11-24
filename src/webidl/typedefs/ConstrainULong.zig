//! WebIDL typedef: ConstrainULong
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const ConstrainULong = union(enum) {
    ulong: u32,
    constrain_ulong_range: dictionaries.ConstrainULongRange,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "ulong", .kind = .numeric },
        .{ .field = "constrain_ulong_range", .kind = .dictionary },
    };
};
