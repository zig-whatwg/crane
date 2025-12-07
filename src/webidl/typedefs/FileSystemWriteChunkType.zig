//! WebIDL typedef: FileSystemWriteChunkType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const FileSystemWriteChunkType = union(enum) {
    buffer_source: typedefs.BufferSource,
    blob: *runtime.Instance,
    usvstring: runtime.USVString,
    write_params: dictionaries.WriteParams,
};
