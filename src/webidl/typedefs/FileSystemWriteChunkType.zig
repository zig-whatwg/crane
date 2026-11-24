//! WebIDL typedef: FileSystemWriteChunkType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const FileSystemWriteChunkType = union(enum) {
    buffer_source: typedefs.BufferSource,
    blob: *runtime.Instance,
    usvstring: runtime.USVString,
    write_params: dictionaries.WriteParams,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "buffer_source", .kind = .buffer_source },
        .{ .field = "blob", .kind = .{ .interface = "Blob" } },
        .{ .field = "usvstring", .kind = .string },
        .{ .field = "write_params", .kind = .dictionary },
    };
};
