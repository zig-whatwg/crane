//! WebIDL typedef: FileSystemWriteChunkType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FileSystemWriteChunkType = union(enum) {
    variant_0: *const anyopaque,
    variant_1: *const anyopaque,
    variant_2: runtime.USVString,
    variant_3: *const anyopaque,
};
