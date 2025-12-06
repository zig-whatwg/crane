//! WebIDL dictionary: EncodedAudioChunkInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EncodedAudioChunkInit = struct {
    type: *const anyopaque,
    timestamp: i64,
    duration: ?u64 = null,
    data: *const anyopaque,
    transfer: ?*const anyopaque = null,
};
