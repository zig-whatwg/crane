//! WebIDL typedef: Uint32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const Uint32List = union(enum) {
    uint32array: runtime.JSValue,
    gluint_sequence: []const typedefs.GLuint,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "uint32array", .kind = .{ .typed_array = "Uint32Array" } },
        .{ .field = "gluint_sequence", .kind = .sequence },
    };
};
