//! WebIDL typedef: Int32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const Int32List = union(enum) {
    int32array: runtime.JSValue,
    glint_sequence: []const typedefs.GLint,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "int32array", .kind = .{ .typed_array = "Int32Array" } },
        .{ .field = "glint_sequence", .kind = .sequence },
    };
};
