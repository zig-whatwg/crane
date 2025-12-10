//! WebIDL dictionary: EncodedAudioChunkInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const EncodedAudioChunkInit = struct {
    @"type": enums.EncodedAudioChunkType,
    timestamp: i64,
    duration: ?u64 = null,
    data: typedefs.AllowSharedBufferSource,
    transfer: ?[]const runtime.JSValue = null,
};
