//! WebIDL dictionary: RTCEncodedVideoFrameMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCEncodedFrameMetadata = @import("RTCEncodedFrameMetadata.zig").RTCEncodedFrameMetadata;

pub const RTCEncodedVideoFrameMetadata = struct {
    // Inherited from RTCEncodedFrameMetadata
    base: RTCEncodedFrameMetadata,

    frameId: ?u64 = null,
    dependencies: ?anyopaque = null,
    width: ?u16 = null,
    height: ?u16 = null,
    spatialIndex: ?u32 = null,
    temporalIndex: ?u32 = null,
    timestamp: ?i64 = null,
};
