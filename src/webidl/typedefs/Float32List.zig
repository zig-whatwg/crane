//! WebIDL typedef: Float32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const Float32List = union(enum) {
    float32array: runtime.JSValue,
    glfloat_sequence: []const typedefs.GLfloat,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "float32array", .kind = .{ .typed_array = "Float32Array" } },
        .{ .field = "glfloat_sequence", .kind = .{ .sequence = null } },
    };
};
