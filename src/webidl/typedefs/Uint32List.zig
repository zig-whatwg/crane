//! WebIDL typedef: Uint32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const Uint32List = union(enum) {
    uint32array: *const anyopaque,
    gluint_sequence: []const typedefs.GLuint,
};
