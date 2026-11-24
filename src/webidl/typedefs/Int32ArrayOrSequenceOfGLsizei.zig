//! WebIDL typedef: Int32ArrayOrSequenceOfGLsizei
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const Int32ArrayOrSequenceOfGLsizei = union(enum) {
    int32array: runtime.JSValue,
    glsizei_sequence: []const typedefs.GLsizei,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "int32array", .kind = .{ .typed_array = "Int32Array" } },
        .{ .field = "glsizei_sequence", .kind = .{ .sequence = null } },
    };
};
