//! WebIDL typedef: BlobPart
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const BlobPart = union(enum) {
    buffer_source: typedefs.BufferSource,
    blob: *runtime.Instance,
    usvstring: runtime.USVString,
};
