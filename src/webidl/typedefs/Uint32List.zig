//! WebIDL typedef: Uint32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const Uint32List = union(enum) {
    uint32array: runtime.JSValue,
    gluint_sequence: []const typedefs.GLuint,
};
