//! WebIDL dictionary: EncodedVideoChunkInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const EncodedVideoChunkInit = struct {
    @"type": enums.EncodedVideoChunkType,
    timestamp: i64,
    duration: ?u64 = null,
    data: typedefs.AllowSharedBufferSource,
    transfer: ?[]const *const anyopaque = null,
};
