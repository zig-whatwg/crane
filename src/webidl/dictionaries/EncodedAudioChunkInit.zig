//! WebIDL dictionary: EncodedAudioChunkInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EncodedAudioChunkInit = struct {
    type: anyopaque,
    timestamp: i64,
    duration: ?u64 = null,
    data: anyopaque,
    transfer: ?anyopaque = null,
};
