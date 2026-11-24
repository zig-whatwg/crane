//! WebIDL typedef: DOMStringOrSequenceOfUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrSequenceOfUUID = union(enum) {
    domstring: runtime.DOMString,
    uuid_sequence: []const typedefs.UUID,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "uuid_sequence", .kind = .{ .sequence = null } },
    };
};
