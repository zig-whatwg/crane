//! WebIDL dictionary: RTCEncodedAudioFrameMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const RTCEncodedFrameMetadata = @import("RTCEncodedFrameMetadata.zig").RTCEncodedFrameMetadata;

pub const RTCEncodedAudioFrameMetadata = struct {
    // Inherited from RTCEncodedFrameMetadata
    base: RTCEncodedFrameMetadata,

    sequenceNumber: ?i16 = null,
    audioLevel: ?f64 = null,
};
