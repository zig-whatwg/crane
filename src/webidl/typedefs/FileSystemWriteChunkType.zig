//! WebIDL typedef: FileSystemWriteChunkType
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const FileSystemWriteChunkType = union(enum) {
    buffer_source: typedefs.BufferSource,
    blob: *runtime.Instance,
    usvstring: runtime.USVString,
    write_params: *runtime.Instance,
};
