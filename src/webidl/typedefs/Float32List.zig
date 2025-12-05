//! WebIDL typedef: Float32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const Float32List = union(enum) {
    float32array: *const anyopaque,
    glfloat_sequence: []const typedefs.GLfloat,
};
