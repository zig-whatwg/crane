//! WebIDL typedef: UnsignedLongOrSequenceOfUnsignedLong
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const UnsignedLongOrSequenceOfUnsignedLong = union(enum) {
    ulong: u32,
    ulong_sequence: []const u32,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "ulong", .kind = .numeric },
        .{ .field = "ulong_sequence", .kind = .{ .sequence = null } },
    };
};
