//! WebIDL typedef: Int32List
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const Int32List = union(enum) {
    int32array: runtime.JSValue,
    glint_sequence: []const typedefs.GLint,
};
